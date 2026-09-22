@tool
extends SettingsTypeList


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	options = TranslationServer.get_loaded_locales()


func apply() -> void:
	print_debug("TODO!")
	#TranslationServer.set_locale(options.get(current_value))
