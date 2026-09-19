@tool
extends Node

const SAVE_PATH: String = "user://settings.cfg"

@export var presets: Array[SettingsPreset] = []

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
	for candidate: SettingsPreset in presets:
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
		input_setting.apply()
	active_input_preset = preset_name
	save()


func rebind_action(setting_key: String, events: Array[InputEvent]) -> void:
	var setting: SettingsType = _settings_map.get(setting_key)
	if not setting is SettingsTypeInput:
		return
	var input_setting: SettingsTypeInput = setting as SettingsTypeInput
	input_setting.current_value = events
	input_setting.apply()
	active_input_preset = ""
	save()
