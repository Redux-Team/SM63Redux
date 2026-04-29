@tool
extends MarginContainer

const DEFAULT_VALUES: Dictionary[String, Variant] = {
	"mute_music": false,
	"mute_sfx": false,
}

const SETTINGS_PATH: String = "res://addons/redux_dev/_local/debug_settings.json"

@export var mute_music: CheckBox
@export var mute_sfx: CheckBox


func _ready() -> void:
	if not is_in_dock():
		return
	
	apply_overrides()
	for key: String in DEFAULT_VALUES:
		var checkbox: CheckBox = _get_checkbox(key)
		if checkbox:
			checkbox.toggled.connect(func(_on: bool) -> void: save_overrides())


func _get_checkbox(key: String) -> CheckBox:
	match key:
		"mute_music": return mute_music
		"mute_sfx": return mute_sfx
	return null


func is_in_dock() -> bool:
	return get_parent() is EditorDock


func save_overrides() -> void:
	var data: Dictionary[String, Variant] = {}
	for key: String in DEFAULT_VALUES:
		var checkbox: CheckBox = _get_checkbox(key)
		var value: bool = checkbox.button_pressed if checkbox else DEFAULT_VALUES[key]
		if value != DEFAULT_VALUES[key]:
			data[key] = value
	
	var dir: DirAccess = DirAccess.open("res://")
	dir.make_dir_recursive("res://addons/redux_dev/_local")
	
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func apply_overrides() -> void:
	var data: Dictionary = DEFAULT_VALUES.duplicate()
	
	if FileAccess.file_exists(SETTINGS_PATH):
		var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed is Dictionary:
			data.merge(parsed, true)
	
	for key: String in data:
		var checkbox: CheckBox = _get_checkbox(key)
		if checkbox:
			checkbox.set_pressed_no_signal(bool(data[key]))


func _on_refresh_plugin_button_pressed() -> void:
	EditorInterface.set_plugin_enabled("redux_dev", false)
	EditorInterface.set_plugin_enabled.call_deferred("redux_dev", true)
