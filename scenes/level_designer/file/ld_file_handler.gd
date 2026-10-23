class_name LDFileHandler
extends LDHandler

signal file_changed

const SESSION_PATH: String = "user://ld/session.cfg"
const LEGACY_BACKUP_SUFFIX: String = ".v1.bak"
const FILTERS: PackedStringArray = ["*.63rl ; Level", "*.json ; Level (JSON)"]

@export var autosave: LDAutosave
@export var title_label: Label
@export var new_button: BaseButton
@export var open_button: BaseButton
@export var save_button: BaseButton
@export var save_as_button: BaseButton
@export var open_dialog: FileDialog
@export var save_dialog: FileDialog
@export var confirm_dialog: ConfirmationDialog

var file_path: String = ""
var _legacy_path: String = ""
var _pending_data: LevelData
var _pending_areas: Array[LevelArea] = []
var _pending_legacy: bool = false
var _saved_version: int = 0
var _pending: Callable


func _unhandled_input(event: InputEvent) -> void:
	if editor.is_shortcut(event, &"ld_save"):
		save()
	elif editor.is_shortcut(event, &"ld_save_as"):
		save_as()
	elif editor.is_shortcut(event, &"ld_open"):
		open()
	elif editor.is_shortcut(event, &"ld_new"):
		new_level()
	else:
		return
	
	get_viewport().set_input_as_handled()


func _setup() -> void:
	DirAccess.make_dir_recursive_absolute(SESSION_PATH.get_base_dir())
	LD.bind_button(new_button, reset_level)
	LD.bind_button(open_button, open)
	LD.bind_button(save_button, save)
	LD.bind_button(save_as_button, save_as)
	open_dialog.filters = FILTERS
	save_dialog.filters = FILTERS
	open_dialog.file_selected.connect(open_path)
	save_dialog.file_selected.connect(save_to)
	confirm_dialog.confirmed.connect(_on_confirmed)
	editor.history_handler.changed.connect(_refresh_title)
	_open_initial()


func has_unsaved_changes() -> bool:
	return editor.history_handler.get_version() != _saved_version


func confirm_discard(callable: Callable) -> void:
	if not has_unsaved_changes():
		callable.call()
		return
	
	confirm("Discard unsaved changes?", callable)


func confirm(text: String, callable: Callable) -> void:
	_pending = callable
	confirm_dialog.dialog_text = text
	confirm_dialog.popup_centered()


func reset_level() -> void:
	confirm("Reset the level? Everything in it will be removed.", _start_new_level)


func new_level() -> void:
	confirm_discard(_start_new_level)


func open() -> void:
	confirm_discard(open_dialog.popup_centered.bind(Vector2i.ZERO))


func open_path(path: String) -> void:
	if Singleton.is_transitioning():
		return
	
	editor.viewport_handler.camera_control.depart()
	(
			Singleton.build_screen_transition()
			.set_blur()
			.set_hold_duration(0.0)
			.set_loading_delay(0.0)
			.add_threaded_task(_prepare.bind(path), _finish_open.bind(path, true))
			.done()
	)


func save() -> void:
	if file_path.is_empty():
		save_as()
	else:
		save_to(file_path)


func save_as() -> void:
	save_dialog.current_path = file_path
	save_dialog.popup_centered()


func save_to(path: String) -> void:
	if path == _legacy_path and not FileAccess.file_exists(path + LEGACY_BACKUP_SUFFIX):
		DirAccess.copy_absolute(path, path + LEGACY_BACKUP_SUFFIX)
	
	var error: Error = LevelFile.write(path, editor.level_handler.capture())
	if error != OK:
		push_error(
				"LDFileHandler: could not save '%s' (%s)." % [
					path,
					error_string(error),
				]
		)
		return
	
	file_path = path
	_remember(path)
	autosave.discard()
	_mark_saved()


func discard_autosave() -> void:
	autosave.discard()


func _open_now(path: String) -> void:
	_prepare(path)
	_finish_open(path)


func _prepare(path: String) -> void:
	_pending_legacy = LevelFile.is_legacy(path)
	_prepare_data(LevelFile.read(path))


func _prepare_data(data: LevelData) -> void:
	_pending_data = data
	_pending_areas = LDLevelHandler.build_areas(data) if data else []


func _finish_open(path: String, reveal: bool = false) -> void:
	if not _apply_pending(path):
		return
	
	_legacy_path = path if _pending_legacy else ""
	_remember(path)
	autosave.discard()
	_mark_saved()
	if reveal:
		await editor.viewport_handler.camera_control.reveal(editor.level_handler.active_area)


func _finish_recovery(path: String) -> void:
	if _apply_pending(path):
		_saved_version = -1
		_refresh_title()


func _apply_pending(path: String) -> bool:
	var data: LevelData = _pending_data
	var built: Array[LevelArea] = _pending_areas
	_pending_data = null
	_pending_areas = []
	if data == null:
		return false
	
	editor.level_handler.open(data, built)
	file_path = path
	return true


func _open_initial() -> void:
	var session: EditorSession = Singleton.editor_session
	var remembered: String = _read_session_path()
	var recovered: LevelData = LevelFile.read(LDAutosave.PATH) if autosave.has_recovery() else null
	var recovery: LevelData = session.level if session.level else recovered
	session.level = null
	if recovery:
		_pending_legacy = false
		editor.level_handler.new_level()
		if not Singleton.defer_threaded(
				_prepare_data.bind(recovery),
				_finish_recovery.bind(remembered),
		):
			_prepare_data(recovery)
			_finish_recovery(remembered)
	elif FileAccess.file_exists(remembered):
		editor.level_handler.new_level()
		if not Singleton.defer_threaded(_prepare.bind(remembered), _finish_open.bind(remembered)):
			_open_now(remembered)
	else:
		_start_new_level()
	
	_refresh_title()


func _start_new_level() -> void:
	editor.level_handler.new_level()
	file_path = ""
	autosave.discard()
	_mark_saved()


func _mark_saved() -> void:
	_saved_version = editor.history_handler.get_version()
	_refresh_title()


func _refresh_title() -> void:
	if title_label:
		var file_name: String = file_path.get_file() if not file_path.is_empty() else "Untitled"
		title_label.text = file_name + (" *" if has_unsaved_changes() else "")
	LD.set_disabled(save_button, not has_unsaved_changes() and not file_path.is_empty())
	file_changed.emit()


func _remember(path: String) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("session", "path", path)
	config.save(SESSION_PATH)


func _read_session_path() -> String:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SESSION_PATH) != OK:
		return ""
	
	return config.get_value("session", "path", "")


func _on_confirmed() -> void:
	var callable: Callable = _pending
	_pending = Callable()
	if callable.is_valid():
		callable.call()
