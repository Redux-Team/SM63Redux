extends PropertyWidget

@export var label: Label
@export var toggle: Button
@export var toggle_dot: Panel


func _name(widget_name: String) -> void:
	label.text = widget_name


func _value(widget_value: Variant) -> void:
	toggle.set_pressed_no_signal(widget_value)
	_update_state(widget_value)


func _on_toggle_toggled(toggled_on: bool) -> void:
	_update_state(toggled_on)
	_commit(toggled_on)


func _update_state(toggled_on: bool) -> void:
	if toggled_on:
		GDSS.set_state(toggle_dot, "on")
	else:
		GDSS.clear_state(toggle_dot)
