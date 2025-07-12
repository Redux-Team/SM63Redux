@tool
## Class for handling the control scheme of the game.
## All variables in this class are automatically pushed
## to the settings menu for the user to modify unless
## the variable is declared private with an underscore.
class_name ControlScheme
extends Resource

const USER = 4102


@warning_ignore_start("unused_private_class_variable")
@export_group("Movement")
@export var move_left: Array[InputEvent]
@export var move_right: Array[InputEvent]
@export var jump: Array[InputEvent]
@export var crouch: Array[InputEvent]
@export var ground_pound: Array[InputEvent]
@export var spin: Array[InputEvent]

@export_group("FLUDD")
@export var use_fludd: Array[InputEvent]
@export var swich_nozzle: Array[InputEvent]

@export_group("Other")
@export var interact: Array[InputEvent]
@export var pause: Array[InputEvent]
@export var skip_dialogue: Array[InputEvent]

## These cannot be overriden by the user
@export_group("Internal")
@export var _ui_back: Array[InputEvent]
@export var _ui_interact: Array[InputEvent]
@export var _ui_left: Array[InputEvent]
@export var _ui_right: Array[InputEvent]
@export var _clear_setting: Array[InputEvent]


@export_tool_button("Update InputMap", "Callable") var _assign_to_map: Callable:
	get():
		return assign_to_map


func _get_user_properties() -> Array[Dictionary]:
	var properties: Array[Dictionary]
	for prop: Dictionary in get_property_list():
		if prop.usage == USER: # 4102 seems to indicate that this prop is user-assigned
			properties.append(prop)
	
	return properties


func get_inputs_string(include_internal: bool = false) -> Array[String]:
	var inputs: Array[String]
	for prop: Dictionary in _get_user_properties():
		if include_internal or not prop.name.begins_with("_"):
			inputs.append(prop.name)
	
	return inputs


func get_active_inputs() -> Dictionary[String, Array]:
	match Singleton.current_input_device:
		Singleton.InputType.KEYBOARD:
			return get_keyboard_inputs()
		Singleton.InputType.CONTROLLER:
			return get_controller_inputs()
		_:
			return {}


func get_keyboard_inputs() -> Dictionary[String, Array]:
	var inputs: Dictionary[String, Array]
	
	for property: Dictionary in _get_user_properties():
		var prop_event_array: Array[InputEvent]
		for input_event: InputEvent in get(property.name):
			if input_event is InputEventKey or input_event is InputEventMouseButton:
				prop_event_array.append(input_event)
		
		inputs.set(property.name, prop_event_array)
	
	return inputs


func get_controller_inputs() -> Dictionary[String, Array]:
	var inputs: Dictionary[String, Array]
	
	for property: Dictionary in _get_user_properties():
		var prop_event_array: Array[InputEvent]
		for input_event: InputEvent in get(property.name):
			if input_event is InputEventJoypadButton or input_event is InputEventJoypadMotion:
				prop_event_array.append(input_event)
		
		inputs.set(property.name, prop_event_array)
	
	return inputs


func get_hint(input: String, icon_size: int = 0) -> String:
	if not get(input):
		push_error("No input found with name '%s'." % input)
		return ""
	
	var inputs: Dictionary[String, Array] = get_active_inputs()
	var events: Array = inputs.get(input, [])
	
	if events.is_empty():
		push_warning("No inputs found for '%s'." % input)
		return ""
	
	var event: InputEvent = events[0]
	
	if Singleton.current_input_device == Singleton.InputType.CONTROLLER:
		var size: String = ""
		
		if icon_size != 0:
			size = "=%s" % icon_size
		 
		return "[img%s]%s[/img]" % [size, Singleton.CONTROLLER_ICONS.from_event(event).resource_path]
	else:
		return event.as_text()


func assign_to_map() -> void:
	for input: String in get_inputs_string(true):
		if InputMap.has_action(input):
			InputMap.action_erase_events(input)
		else:
			InputMap.add_action(input)
		
		for event: InputEvent in get(input):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				event.device = -1
			InputMap.action_add_event(input, event)
		
		# For the editor
		#for property: Dictionary in ProjectSettings.get_property_list():
			#if property.name.begins_with("input/"):
				#print(property)
		ProjectSettings.set_setting("input/%s" % input, get(input))
