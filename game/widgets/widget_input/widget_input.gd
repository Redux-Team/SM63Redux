extends PropertyWidget

@export var label: Label
@export var bindings: HBoxContainer


func _name(widget_name: String) -> void:
	label.text = widget_name


func _value(widget_value: Variant) -> void:
	for child: Node in bindings.get_children():
		bindings.remove_child(child)
		child.queue_free()
	for event: InputEvent in widget_value:
		var event_label: Label = Label.new()
		event_label.text = _event_text(event)
		GDSS.add_class(event_label, "InputBinding")
		bindings.add_child(event_label)


func _event_text(event: InputEvent) -> String:
	if event is InputEventKey:
		return OS.get_keycode_string(
				DisplayServer.keyboard_get_keycode_from_physical(
						(event as InputEventKey).physical_keycode
				)
		)
	if event is InputEventMouseButton:
		return "Mouse %d" % (event as InputEventMouseButton).button_index
	if event is InputEventJoypadButton:
		return "Pad %d" % (event as InputEventJoypadButton).button_index
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
		return "Axis %d%s" % [
			motion.axis,
			"+" if motion.axis_value > 0.0 else "-",
		]
	return event.as_text()
