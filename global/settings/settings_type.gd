@tool
@abstract class_name SettingsType
extends Node


@export var setting_key: String
@export var name_override: String = ""
@export var requires_apply: bool = true
@warning_ignore("unused_private_class_variable")
@export_tool_button("Refresh Properties", "Reload") var _refresh_properties: Callable:
	get: return func() -> void:
		notify_property_list_changed()


@abstract func _serialize() -> String
@abstract func _deserialize(string: String) -> void
@abstract func _get_default_value() -> Variant
@abstract func _restore_default() -> void
@abstract func _get_value() -> Variant


func apply() -> void:
	if not requires_apply:
		return
	var category: SettingsCategory = get_parent() as SettingsCategory
	if category == null:
		push_error("Settings: '%s' is not parented to a category." % setting_key)
		return
	category._apply_setting(self)


func value() -> Variant:
	return _get_value()


func display_name() -> String:
	return name_override if not name_override.is_empty() else String(name)
