class_name ControlScheme
extends Resource

const USER = 4102

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


func _get_user_properties() -> Array[Dictionary]:
	var properties: Array[Dictionary]
	for prop: Dictionary in get_property_list():
		if prop.usage == USER: # 4102 seems to indicate that this prop is user-assigned
			properties.append(prop)
	
	return properties


func get_inputs_string() -> Array[String]:
	var inputs: Array[String]
	for prop: Dictionary in _get_user_properties():
		inputs.append(prop.name)
	
	return inputs


func get_keyboard_inputs() -> Dictionary[String, Array]:
	var inputs: Dictionary[String, Array]
	
	for property: Dictionary in _get_user_properties():
		var prop_event_array: Array[InputEvent]
		for input_event: InputEvent in get(property.name):
			if input_event is InputEventKey:
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
