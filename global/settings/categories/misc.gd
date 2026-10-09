@tool
class_name SettingsCategoryMisc
extends SettingsCategory

@export var language: SettingsTypeList
@export var force_touch_controls: SettingsTypeBoolean


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	language.options = TranslationServer.get_loaded_locales()


func _apply_setting(setting: SettingsType) -> void:
	match setting:
		language:
			print_debug("TODO!")
			#TranslationServer.set_locale(options.get(current_value))
		force_touch_controls:
			print_debug("TODO!")
		_:
			super(setting)
