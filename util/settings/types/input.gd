@tool
class_name SettingsTypeInput
extends SettingsType


@export var default_value: Array[InputEvent]
var current_value: Array[InputEvent]


func _serialize() -> String:
	var actions: PackedStringArray = PackedStringArray()
	actions.resize(current_value.size())
	
	for i: int in current_value.size():
		var event: InputEvent = current_value.get(i)
		actions.set(i, InputUtil.event_to_string(event))
	
	return ";".join(actions)


func _deserialize(string: String) -> void:
	var actions: PackedStringArray = string.split(";")
	
	current_value.clear()
	current_value.resize(actions.size())
	
	for i: int in actions.size():
		var action_string: String = actions.get(i)
		var event: InputEvent = InputUtil.string_to_event(action_string)
		current_value.set(i, event)


func _get_default_value() -> Variant:
	return default_value


func _restore_default() -> void:
	current_value = default_value.duplicate()


func apply() -> void:
	if not InputMap.has_action(setting_key):
		InputMap.add_action(setting_key)
	InputMap.action_erase_events(setting_key)
	for event: InputEvent in current_value:
		InputMap.action_add_event(setting_key, event)
