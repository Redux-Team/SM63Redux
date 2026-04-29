extends Node

const SETTINGS_PATH: String = "res://addons/redux_dev/_local/debug_settings.json"

const DEFAULT_VALUES: Dictionary[String, Variant] = {
	"mute_music": false,
	"mute_sfx": false,
}

var APPLIERS: Dictionary[String, Callable] = {
	"mute_music": func(value: bool) -> void:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), value),
	"mute_sfx": func(value: bool) -> void:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), value),
}


func _ready() -> void:
	var data: Dictionary = DEFAULT_VALUES.duplicate()
	
	if FileAccess.file_exists(SETTINGS_PATH):
		var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed is Dictionary:
			data.merge(parsed, true)
	
	for key: String in APPLIERS:
		APPLIERS[key].call(data.get(key, DEFAULT_VALUES.get(key)))
