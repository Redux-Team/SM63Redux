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
	_set_range(prop.get_range())
	_set_unbound(prop.is_unbound())
	_set_arrow_step(prop.get_arrow_step())
	_set_step(prop.get_step())
	_set_value(current_value)
	if prop.exclusive:
		_hide_reset()
	else:
		_update_reset_button(current_value)




@warning_ignore("unused_parameter")
func _set_range(limits: Vector2) -> void:
	pass


@warning_ignore("unused_parameter")
func _set_step(step: float) -> void:
	pass


@warning_ignore("unused_parameter")
func _set_arrow_step(step: float) -> void:
	pass


func _set_unbound(unbound: bool) -> void:
	pass


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
