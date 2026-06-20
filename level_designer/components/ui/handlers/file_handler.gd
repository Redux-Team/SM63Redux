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
@export var _save_button: Button


## Set while a save-as is being routed through the file dialog on the way to quitting, so the app
## closes once the file has actually been written (or stays put if the dialog is dismissed).
var _quitting: bool = false


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
	var history: LDHistoryHandler = LD.get_history_handler()
	if history and not history.history_changed.is_connected(_update_save_buttons):
		history.history_changed.connect(_update_save_buttons)
	_save_file_dialog.canceled.connect(_on_save_dialog_canceled)
	Singleton.set_quit_guard(_on_quit_requested)
	_update_save_buttons()


func _exit_tree() -> void:
	Singleton.clear_quit_guard(_on_quit_requested)


## Intercepts an app-close request: with unsaved changes, prompt to save first and report that the
## quit is being handled; otherwise let it proceed.
func _on_quit_requested() -> bool:
	if not LD.get_save_load_handler().is_dirty():
		return false
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Unsaved Changes"
	dialog.dialog_text = "You have unsaved changes. Save before quitting?"
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


## Saves and then quits; with no file yet, routes through the save dialog (quitting once written).
func _save_then_quit() -> void:
	var handler: LDSaveLoadHandler = LD.get_save_load_handler()
	if handler.has_loaded_file():
		handler.save_current()
		get_tree().quit()
	else:
		_quitting = true
		_save_file_dialog.popup_centered()


func _on_save_dialog_canceled() -> void:
	_quitting = false


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
		.set_in_duration(0.5) \
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
		_quitting = false
		return
	if _quitting:
		_quitting = false
		get_tree().quit()


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
	var handler: LDSaveLoadHandler = LD.get_save_load_handler()
	if is_instance_valid(_save_new_button):
		_save_new_button.visible = handler.has_loaded_file()
	GDSS.set_disabled(_save_button, handler.has_loaded_file() and not handler.is_dirty())


#endregion
