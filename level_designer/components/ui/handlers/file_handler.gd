class_name LDUIFileHandler
extends Node

## Level-level actions: save / save-as / load / reset, plus launching a playtest. Owns
## the save/load/reset dialogs and keeps the "Save As..." button's visibility in sync.
## Reached via LD.get_ui().get_file_handler().

const PLAYTEST_SCENE: String = "uid://ctssku6r3gx0a"
const WAVE_MASK: Texture2D = preload("uid://c0rwnbt8w3qel")


@export var _save_file_dialog: FileDialog
@export var _load_file_dialog: FileDialog
@export var _reset_level_dialog: ConfirmationDialog
@export var _save_new_button: Button


func _ready() -> void:
	var filters: PackedStringArray = PackedStringArray([
		"*.63rl;63 Redux Level",
		"*.json;JSON Level",
	])
	_save_file_dialog.filters = filters
	_load_file_dialog.filters = filters


## Called by LDUI once the level designer is fully ready.
func setup() -> void:
	LD.get_save_load_handler().file_state_changed.connect(_update_save_buttons)
	_update_save_buttons()


#region Buttons

func _on_save_button_pressed() -> void:
	var handler: LDSaveLoadHandler = LD.get_save_load_handler()
	if handler.has_loaded_file():
		handler.save_current()
	else:
		_save_file_dialog.popup_centered()


func _on_save_new_button_pressed() -> void:
	_save_file_dialog.popup_centered()


func _on_load_button_pressed() -> void:
	_load_file_dialog.popup_centered()


func _on_reset_button_pressed() -> void:
	_reset_level_dialog.popup_centered()


func _on_test_server_button_pressed() -> void:
	#Singleton.get_multiplayer_handler().start_server()
	Singleton.set_meta("playtest", LD.get_save_load_handler().get_level_data())
	LD.get_save_load_handler().save_session()
	# Wave-in: cover the editor, switch to the playtest, then reveal it (the shine select or level).
	Singleton.build_screen_transition() \
		.set_wave() \
		.set_texture(WAVE_MASK) \
		.set_wave_scale(4.0) \
		.set_destination(PLAYTEST_SCENE) \
		.done()


func _on_test_client_button_pressed() -> void:
	Singleton.get_multiplayer_handler().start_client()
	Singleton.set_meta("playtest", LD.get_save_load_handler().get_level_data())
	get_tree().change_scene_to_file("uid://ctssku6r3gx0a")


#endregion


#region Dialog results

func _on_save_file_selected(path: String) -> void:
	var handler: LDSaveLoadHandler = LD.get_save_load_handler()
	var err: Error
	if path.get_extension() == "json":
		err = handler.save_json(path)
	else:
		err = handler.save_binary(path)
	if err != OK:
		push_error("Failed to save level: " + error_string(err))


func _on_load_file_selected(path: String) -> void:
	var handler: LDSaveLoadHandler = LD.get_save_load_handler()
	var err: Error
	if path.ends_with(".json"):
		err = handler.load_json(path)
	else:
		err = handler.load_binary(path)
	if err != OK:
		push_error("Failed to load level: " + error_string(err))


func _on_reset_level_dialog_confirmed() -> void:
	LD.get_save_load_handler().reset_level()


func _update_save_buttons() -> void:
	if is_instance_valid(_save_new_button):
		_save_new_button.visible = LD.get_save_load_handler().has_loaded_file()


#endregion
