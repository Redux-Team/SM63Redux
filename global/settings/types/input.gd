@tool
class_name SettingsTypeInput
extends SettingsType


@export var default_value: Array[InputEvent]
var current_value: Array[InputEvent] = []:
	set(value):
		current_value = value
		apply()


func _serialize() -> String:
	var actions: PackedStringArray = PackedStringArray()
	actions.resize(current_value.size())
	
	for i: int in current_value.size():
		var event: InputEvent = current_value.get(i)
		actions.set(i, InputUtil.event_to_string(event))
	
	return ";".join(actions)


func _deserialize(string: String) -> void:
	var actions: PackedStringArray = string.split(";")
	var events: Array[InputEvent] = []
	events.resize(actions.size())
	
	for i: int in actions.size():
		var action_string: String = actions.get(i)
		events.set(i, InputUtil.string_to_event(action_string))
	
	current_value = events


func _get_default_value() -> Variant:
	return default_value


func _restore_default() -> void:
	current_value = default_value.duplicate()


func _get_value() -> Variant:
	return current_value


func apply() -> void:
	if not InputMap.has_action(setting_key):
		InputMap.add_action(setting_key)
	InputMap.action_erase_events(setting_key)
	for event: InputEvent in current_value:
		InputMap.action_add_event(setting_key, event)


func binding() -> PropertyBinding:
	var getter: Callable = func() -> Variant:
		return current_value
	var setter: Callable = func(value: Variant) -> void:
		Settings.rebind_action(self, value)
	return PropertyBinding.new(getter, setter, display_name(), {"type": TYPE_ARRAY, "hint": PROPERTY_HINT_ARRAY_TYPE, "hint_string": "InputEvent"})


func pressed() -> bool:
	return Input.is_action_pressed(setting_key)


func just_pressed() -> bool:
	return Input.is_action_just_pressed(setting_key)


func just_released() -> bool:
	return Input.is_action_just_released(setting_key)


func strength() -> float:
	return Input.get_action_strength(setting_key)
