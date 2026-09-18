class_name InputUtil


static func event_to_string(event: InputEvent) -> String:
	if event is InputEventKey:
		return "k:%d" % event.physical_keycode
	if event is InputEventJoypadButton:
		return "c:%d" % event.button_index
	if event is InputEventJoypadMotion:
		return "a:%d,%d" % [event.axis, sign(event.axis_value)]
	if event is InputEventMouseButton:
		return "m:%d" % event.button_index
	return ""


static func string_to_event(string: String) -> InputEvent:
	var parts: PackedStringArray = string.split(":", true, 1)
	var prefix: String = parts.get(0)
	if prefix == "a":
		var axis_parts: PackedStringArray = parts.get(1).split(",", true, 1)
		var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
		event.axis = axis_parts.get(0).to_int() as JoyAxis
		event.axis_value = axis_parts.get(1).to_int()
		return event
	var value: int = parts.get(1).to_int()
	if prefix == "k":
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = value as Key
		return event
	if prefix == "c":
		var event: InputEventJoypadButton = InputEventJoypadButton.new()
		event.button_index = value as JoyButton
		return event
	if prefix == "m":
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = value as MouseButton
		return event
	return null
