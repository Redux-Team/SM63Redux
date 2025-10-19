@tool
class_name ControlScheme
extends Resource
## Class for handling and exposing game control schemes.
## All exported variables are auto-added to settings menu (except those prefixed with a `_`).
## Static functions are provided to easily access and modify the current control scheme.

@warning_ignore_start("unused_private_class_variable")
@export_group("Movement")
@export var move_left: Array[InputEvent]
@export var move_right: Array[InputEvent]
@export var jump: Array[InputEvent]
@export var crouch: Array[InputEvent]
@export var dive: Array[InputEvent]
@export var ground_pound: Array[InputEvent]
@export var spin: Array[InputEvent]

@export_group("FLUDD")
@export var use_fludd: Array[InputEvent]
@export var switch_nozzle: Array[InputEvent]

@export_group("Other")
@export var interact: Array[InputEvent]
@export var pause: Array[InputEvent]
@export var skip_dialogue: Array[InputEvent]

## Internal use only, not user-overridable via settings
@export_group("Internal")
@export var _ui_back: Array[InputEvent]
@export var _ui_interact: Array[InputEvent]
@export var _ui_left: Array[InputEvent]
@export var _ui_right: Array[InputEvent]
@export var _clear_setting: Array[InputEvent]

@export_tool_button("Update InputMap", "Callable") var __assign_to_map: Callable:
	get(): return assign_to_map
#
#@export_category("Other Controls")
#@export var __controller_icon_map: Dictionary[InputEvent, Texture2D]
#@export var __touch_controls: Dictionary[StringName, TouchButtonSetting]
#
#@export_tool_button("Refresh Touch Controls", "Callable") var __refresh_touch_controls_button: Callable:
	#get(): return _regenerate_touch_controls


## Returns a deep copy of given control_scheme
static func copy_from(control_scheme: ControlScheme) -> ControlScheme:
	var cs: ControlScheme = ControlScheme.new()
	for prop: Dictionary in control_scheme._get_user_properties():
		var control_scheme_events: Array[InputEvent] = control_scheme.get(prop.name).duplicate(true)
		var cs_events: Array[InputEvent]
		for event: InputEvent in control_scheme_events:
			cs_events.append(event.duplicate(true))
		cs.set(prop.name, cs_events)
	return cs


## Return hint string for input via underlying Config singleton
static func get_hint(hint_string: String) -> String:
	return Config.get_control_scheme().get_hint_string(hint_string)


## Get raw events array by name from current control scheme
static func get_events(name: String) -> Array[InputEvent]:
	return Config.get_control_scheme().get(name)


## Set raw events array by name for current control scheme
static func set_events(name: String, inputs: Array[InputEvent]) -> void:
	Config.get_control_scheme().set(name, inputs)


## Get active events filtered by device type (keyboard/controller/any)
static func get_active_events(name: String, from: InputEvent = null) -> Array[InputEvent]:
	if from is InputEventKey:
		return Config.get_control_scheme().get_keyboard_inputs().get(name)
	if from is InputEventJoypadButton or from is InputEventJoypadMotion:
		return Config.get_control_scheme().get_controller_inputs().get(name)
	# fallback to all
	return Config.get_control_scheme().get_active_inputs().get(name)


## Reapply current scheme to InputMap via Config wrapper
static func update_input_map() -> void:
	Config.get_control_scheme().assign_to_map()


## Returns array of dictionaries for all user-visible properties
func _get_user_properties() -> Array[Dictionary]:
	var properties: Array[Dictionary]
	for prop: Dictionary in get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and not prop.name.begins_with("__"):
			properties.append(prop)
	return properties


## Return list of property names; optional include internal (`_`) ones
func get_inputs_string(include_internal: bool = false) -> Array[String]:
	var inputs: Array[String]
	for prop: Dictionary in _get_user_properties():
		if include_internal or not prop.name.begins_with("_"):
			inputs.append(prop.name)
	return inputs


## Device-aware lookup: keyboard/controller/empty map
func get_active_inputs() -> Dictionary[String, Array]:
	match Singleton.current_input_device:
		Singleton.InputType.KEYBOARD:
			return get_keyboard_inputs()
		Singleton.InputType.CONTROLLER:
			return get_controller_inputs()
		_:
			return {}


## Collect keyboard and mouse InputEvents only
func get_keyboard_inputs() -> Dictionary[String, Array]:
	var inputs: Dictionary[String, Array]
	for property: Dictionary in _get_user_properties():
		var prop_event_array: Array[InputEvent]
		for input_event: InputEvent in get(property.name):
			if input_event is InputEventKey or input_event is InputEventMouseButton:
				prop_event_array.append(input_event)
		inputs.set(property.name, prop_event_array)
	return inputs


## Collect controller InputEvents only (buttons/motion)
func get_controller_inputs() -> Dictionary[String, Array]:
	var inputs: Dictionary[String, Array]
	for property: Dictionary in _get_user_properties():
		var prop_event_array: Array[InputEvent]
		for input_event: InputEvent in get(property.name):
			if input_event is InputEventJoypadButton or input_event is InputEventJoypadMotion:
				prop_event_array.append(input_event)
		inputs.set(property.name, prop_event_array)
	return inputs


## Sync all inputs (including internal) to Godot's InputMap + ProjectSettings
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
		ProjectSettings.set_setting("input/%s" % input, get(input))


## Build hint string or controller icon from first active event
func get_hint_string(input: String, icon_size: int = 0) -> String:
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
		return "[img%s]%s[/img]" % [size, Config.input.get_controller_icon(event).resource_path]
	else:
		return event.as_text()
