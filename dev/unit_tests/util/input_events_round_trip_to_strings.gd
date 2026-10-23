@tool
static func run_test() -> void:
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	assert(InputUtil.event_to_string(key) == "k:%d" % KEY_SPACE)
	var key_back: InputEventKey = InputUtil.string_to_event(InputUtil.event_to_string(key))
	assert(key_back.physical_keycode == KEY_SPACE)
	
	var button: InputEventJoypadButton = InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	var button_back: InputEventJoypadButton = \
			InputUtil.string_to_event(InputUtil.event_to_string(button))
	assert(button_back.button_index == JOY_BUTTON_A)
	
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	assert(InputUtil.event_to_string(mouse) == "m:%d" % MOUSE_BUTTON_RIGHT)
	var mouse_back: InputEventMouseButton = \
			InputUtil.string_to_event(InputUtil.event_to_string(mouse))
	assert(mouse_back.button_index == MOUSE_BUTTON_RIGHT)
	
	for axis_value: float in [-0.8, 0.6]:
		var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
		motion.axis = JOY_AXIS_LEFT_Y
		motion.axis_value = axis_value
		assert(
				InputUtil.event_to_string(motion)
				== "a:%d,%d" % [JOY_AXIS_LEFT_Y, signf(axis_value)]
		)
		var motion_back: InputEventJoypadMotion = \
				InputUtil.string_to_event(InputUtil.event_to_string(motion))
		assert(motion_back.axis == JOY_AXIS_LEFT_Y)
		assert(motion_back.axis_value == signf(axis_value))
	
	assert(InputUtil.event_to_string(InputEventMouseMotion.new()) == "")
	assert(InputUtil.string_to_event("z:5") == null)
	for malformed: String in ["", "k", "a:3"]:
		assert(InputUtil.string_to_event(malformed) == null)
	
	var expected: Array[InputEvent] = [key, button, mouse]
	var serialized: PackedStringArray = []
	for event: InputEvent in expected:
		serialized.append(InputUtil.event_to_string(event))
	var parsed: PackedStringArray = []
	for part: String in ";".join(serialized).split(";"):
		parsed.append(InputUtil.event_to_string(InputUtil.string_to_event(part)))
	assert(parsed == serialized)
