@tool
class_name SettingsCategoryMisc
extends SettingsCategory

@export var language: SettingsTypeList
@export var force_touch_controls: SettingsTypeBoolean
@export var discord_rpc: SettingsTypeList


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
		discord_rpc:
			Singleton.set_discord_mode(discord_rpc.current_value as Singleton.DiscordMode)
		_:
			super(setting)


func _get_ignored_settings() -> Array[SettingsType]:
	var ignored: Array[SettingsType] = []
	if OS.has_feature("web") or OS.has_feature("mobile"):
		ignored.append(discord_rpc)
	return ignored
