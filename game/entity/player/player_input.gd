class_name PlayerInput
extends RefCounted

const ACTIONS: Array[StringName] = [
	&"jump",
	&"crouch",
	&"dive",
	&"ground_pound",
	&"spin",
	&"use_fludd",
	&"switch_nozzle",
]

var move: float = 0.0
var swim: float = 0.0

var _press_ages: Dictionary[StringName, float] = {}


func poll(delta: float) -> void:
	move = Input.get_axis(&"move_left", &"move_right")
	swim = Input.get_axis(&"swim_up", &"swim_down")
	for action: StringName in ACTIONS:
		if Input.is_action_just_pressed(action):
			_press_ages.set(action, 0.0)
		elif _press_ages.has(action):
			_press_ages.set(action, _press_ages.get(action) + delta)


func is_held(action: StringName) -> bool:
	return Input.is_action_pressed(action)


func is_just_pressed(action: StringName) -> bool:
	return _press_ages.get(action, INF) == 0.0


func is_buffered(action: StringName, window: float) -> bool:
	return is_held(action) and was_pressed_within(action, window)


func was_pressed_within(action: StringName, window: float) -> bool:
	return _press_ages.get(action, INF) <= window


func consume(action: StringName) -> void:
	_press_ages.erase(action)
