@tool

const SETTINGS: PackedScene = preload("res://global/settings/settings.tscn")


static func run_test() -> void:
	var boolean: SettingsTypeBoolean = SettingsTypeBoolean.new()
	boolean.requires_apply = false
	boolean.default_value = false
	boolean._restore_default()
	assert(boolean.value() == false)
	boolean.current_value = true
	assert(boolean._serialize() == "true")
	boolean._deserialize("false")
	assert(boolean.value() == false)
	boolean._deserialize("garbage")
	assert(boolean.value() == false)
	boolean.free()
	
	var number: SettingsTypeFloat = SettingsTypeFloat.new()
	number.requires_apply = false
	number.minimum = 0.0
	number.maximum = 2.0
	number.current_value = 5.0
	assert(is_equal_approx(number.value(), 2.0))
	number.current_value = -1.0
	assert(is_equal_approx(number.value(), 0.0))
	number._deserialize("1.25")
	assert(is_equal_approx(number.value(), 1.25))
	number._deserialize(number._serialize())
	assert(is_equal_approx(number.value(), 1.25))
	number.free()
	
	var list: SettingsTypeList = SettingsTypeList.new()
	list.requires_apply = false
	list.options = ["Low", "Medium", "High"]
	list.default_value = 1
	list._restore_default()
	assert(list.value() == "Medium")
	assert(list._get_default_value() == "Medium")
	list.current_value = 10
	assert(list.value() == "High")
	list._deserialize("Low")
	assert(list.current_value == 0)
	list._deserialize("Missing")
	assert(list.current_value == 1)
	list.free()
	
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	var button: InputEventJoypadButton = InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = -1.0
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	for event: InputEvent in [key, button, motion, mouse]:
		var restored: InputEvent = InputUtil.string_to_event(InputUtil.event_to_string(event))
		assert(restored != null)
		assert(restored.get_class() == event.get_class())
		assert(InputUtil.event_to_string(restored) == InputUtil.event_to_string(event))
	assert(InputUtil.string_to_event("x:1") == null)
	
	var settings: Node = SETTINGS.instantiate()
	var keys: PackedStringArray = []
	for setting: SettingsType in settings.find_children("*", "SettingsType", true, false):
		assert(not setting.setting_key.is_empty())
		assert(not keys.has(setting.setting_key))
		assert(setting.get_parent() is SettingsCategory)
		keys.append(setting.setting_key)
		if setting is SettingsTypeList:
			var options: PackedStringArray = (setting as SettingsTypeList).options
			assert(options.is_empty() or (setting as SettingsTypeList).default_value < options.size())
		elif setting is SettingsTypeFloat:
			var range_setting: SettingsTypeFloat = setting
			assert(range_setting.minimum <= range_setting.default_value and range_setting.default_value <= range_setting.maximum)
		elif setting is SettingsTypeInput:
			for event: InputEvent in (setting as SettingsTypeInput).default_value:
				assert(not InputUtil.event_to_string(event).is_empty())
	
	assert(keys.size() > 10)
	settings.free()
