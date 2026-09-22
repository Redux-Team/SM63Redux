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
@abstract func _set_value(val: Variant) -> void

# We can't compile-enforce these to be overridden since there's a type
# abstraction in between but this should do the trick
func apply() -> void:
	assert(not requires_apply, "The apply method must be overridden! (%s)" % self)


func value() -> Variant:
	return _get_value()


func set_value(new_value: Variant) -> void:
	_set_value(new_value)
	apply()


func display_name() -> String:
	return name_override if not name_override.is_empty() else String(name)
