@warning_ignore_start("unused_signal")
@warning_ignore_start("unused_parameter")
class_name LDPropertyWidget
extends Control


signal value_changed(key: StringName, value: Variant)


var _key: StringName
var _default_value: Variant


func setup(prop: LDProperty, current_value: Variant) -> void:
	_key = prop.key
	_default_value = prop.default_value
	_set_label(prop.label)
	_set_value(current_value)
	_update_reset_button(current_value)
	if prop.exclusive:
		_update_reset_button(_default_value)


func _on_property_applied(value: Variant) -> void:
	pass


func _update_reset_button(current_value: Variant) -> void:
	pass

func _set_label(text: String) -> void:
	pass


func _set_value(value: Variant) -> void:
	pass


func _hide_reset() -> void:
	pass
