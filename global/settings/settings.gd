@tool
extends Node

const SAVE_PATH: String = "user://settings.cfg"

@export var display: SettingsCategoryDisplay
@export var graphics: SettingsCategoryGraphics
@export var ui: SettingsCategoryUI
@export var input: SettingsCategoryInput
@export var audio: SettingsCategoryAudio
@export var gameplay: SettingsCategoryGameplay
@export var misc: SettingsCategoryMisc
@export var input_presets: Array[SettingsPreset] = []

var active_input_preset: String = ""
var _settings_map: Dictionary[String, SettingsType] = {}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_build_settings_map(self)
	self.load()


func _build_settings_map(node: Node) -> void:
	for child: Node in node.get_children():
		if child is SettingsType:
			_settings_map.set(child.setting_key, child)
		_build_settings_map(child)


func save() -> void:
	var config: ConfigFile = ConfigFile.new()
	for setting_key: String in _settings_map.keys():
		var setting: SettingsType = _settings_map.get(setting_key)
		config.set_value(setting.get_parent().name, setting_key, setting._serialize())
	config.set_value("Input", "active_preset", active_input_preset)
	config.set_value("metadata", "version", Singleton.get_version().as_string())
	config.save(SAVE_PATH)


func load() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		restore_defaults()
		return
	for setting_key: String in _settings_map.keys():
		var setting: SettingsType = _settings_map.get(setting_key)
		var section: String = setting.get_parent().name
		if config.has_section_key(section, setting_key):
			setting._deserialize(config.get_value(section, setting_key))
		else:
			setting._restore_default()
		setting.apply()
	active_input_preset = config.get_value("Input", "active_preset", "") as String


func restore_defaults() -> void:
	for setting: SettingsType in _settings_map.values():
		setting._restore_default()
		setting.apply()
	active_input_preset = ""
	save()


func apply_preset(preset_name: String) -> void:
	var preset: SettingsPreset = null
	for candidate: SettingsPreset in input_presets:
		if candidate.preset_name == preset_name:
			preset = candidate
			break
	if preset == null:
		return
	for binding: SettingsBinding in preset.bindings:
		var setting: SettingsType = _settings_map.get(binding.setting_key)
		if not setting is SettingsTypeInput:
			continue
		var input_setting: SettingsTypeInput = setting as SettingsTypeInput
		input_setting.current_value = binding.events
	active_input_preset = preset_name
	save()


func rebind_action(action: SettingsTypeInput, events: Array[InputEvent]) -> void:
	action.current_value = events
	active_input_preset = ""
	save()


func get_settings_str(format: String = "\"%s\" = %s;") -> String:
	var settings_str: String = ""
	
	for setting: SettingsType in _settings_map.values():
		settings_str += format % [setting.setting_key, setting.value()]
	
	return settings_str
