class_name LevelRuntime
extends Node2D

## Plays a level from the dict handed over in the "playtest" Singleton meta (set by the
## level designer before switching scenes). Returns to the editor via the back button.

const LEVEL_DESIGNER_SCENE: String = "uid://cf4yw3eqr2qo6"
const SHINE_SELECT_SCENE: PackedScene = preload("res://game/scenes/shine_select/shine_select.tscn")
const SHINE_MASK: Texture2D = preload("uid://daf1pd02jpku1")
const MARIO_MASK: Texture2D = preload("uid://34v4s1d3h4ag")

@export var level_root: Node2D


var _level: Level
var _data: Dictionary


func _ready() -> void:
	Singleton.set_quit_guard(_on_quit_requested)
	_data = Singleton.get_meta("playtest")
	# Offer the shine select when the level has selectable shine scenarios; otherwise (only the
	# COMMON baseline, or no scenario flagged as a shine) jump straight into the level.
	var shines: Array[Dictionary] = _get_shine_scenarios()
	if shines.is_empty():
		_start_level(0)
	else:
		_show_shine_select(shines)


## Numbered scenarios (index >= 1) flagged to appear on the shine select, sorted by index.
func _get_shine_scenarios() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var scenarios: Variant = _data.get("scenarios", {})
	if not scenarios is Dictionary:
		return result
	for entry: Variant in (scenarios as Dictionary).get("scenarios", []):
		if not entry is Dictionary:
			continue
		var index: int = int((entry as Dictionary).get("index", 0))
		if index >= 1 and bool((entry as Dictionary).get("show_in_shine_select", true)):
			result.append({
				"index": index,
				"name": str((entry as Dictionary).get("display_name", "")),
				"area_name": str((entry as Dictionary).get("area_name", "")),
			})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("index", 0)) < int(b.get("index", 0)))
	return result


func _show_shine_select(shines: Array[Dictionary]) -> void:
	var screen: ShineSelect = SHINE_SELECT_SCENE.instantiate()
	add_child(screen)
	screen.scenario_chosen.connect(func(index: int) -> void:
		Singleton.build_screen_transition() \
		.set_in_texture(MARIO_MASK) \
		.set_out_texture(SHINE_MASK) \
		.set_center() \
		.load(func() -> void:
			screen.queue_free()
			_start_level(index)
		).done()
	)
	screen.setup(_data, shines)


func _start_level(scenario_index: int) -> void:
	_level = Level.instantiate()
	_level.name = "Level"
	level_root.add_child(_level)
	_level.kickout_requested.connect(_on_kickout_requested)
	_level.load_from_dict(_data, scenario_index)
	Singleton.get_level_clock().start()


## Collecting a kickout shine removes the player from the level. In a playtest that means covering
## with the shine mask and returning to the level designer.
func _on_kickout_requested() -> void:
	Singleton.get_level_clock().stop()
	_reset_audio_effects()
	Singleton.build_screen_transition() \
		.set_center() \
		.set_out_texture(SHINE_MASK) \
		.set_in_texture(MARIO_MASK) \
		.set_destination(LEVEL_DESIGNER_SCENE) \
		.done()


func _on_back_button_pressed() -> void:
	Singleton.get_level_clock().stop()
	_reset_audio_effects()
	get_tree().change_scene_to_file(LEVEL_DESIGNER_SCENE)


func _exit_tree() -> void:
	Singleton.clear_quit_guard(_on_quit_requested)


## Intercepts an app-close request during a playtest: if the level being tested has unsaved edits,
## prompt to save first; otherwise let the app close.
func _on_quit_requested() -> bool:
	if not _is_dirty():
		return false
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Unsaved Changes"
	dialog.dialog_text = "The level has unsaved changes. Save before quitting?"
	dialog.ok_button_text = "Save"
	var dont_save: Button = dialog.add_button("Don't Save", true, "dont_save")
	dont_save.pressed.connect(func() -> void:
		dialog.queue_free()
		get_tree().quit()
	)
	dialog.confirmed.connect(func() -> void:
		dialog.queue_free()
		_save_then_quit()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()
	return true


## True when the level played here differs from the version last written to disk.
func _is_dirty() -> bool:
	if not Singleton.has_meta(LDSaveLoadHandler.SAVED_HASH_META):
		return true
	return LDSaveLoadHandler.content_hash(_data) != Singleton.get_meta(LDSaveLoadHandler.SAVED_HASH_META)


## Writes the playtested level back to its file and quits; if it was never saved to a real file,
## returns to the editor so the user can choose where to save instead.
func _save_then_quit() -> void:
	if LDSaveLoadHandler.save_to_session_file(_data):
		get_tree().quit()
	else:
		_on_back_button_pressed()


## Strips any runtime-added master-bus effects (e.g. underwater filtering) so they don't
## carry over into the editor after returning.
func _reset_audio_effects() -> void:
	while AudioServer.get_bus_effect_count(0) > 0:
		AudioServer.remove_bus_effect(0, 0)
