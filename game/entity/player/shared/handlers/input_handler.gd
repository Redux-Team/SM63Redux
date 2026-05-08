class_name PlayerInputHandler
extends Node


var player: Player:
	get:
		return owner as Player


func get_x_axis() -> float:
	return Input.get_axis("move_left", "move_right") * (1 if (abs(player.rotation) < PI / 2) else -1)


func get_x_dir() -> float:
	return sign(get_x_axis())


func is_action_pressed(action: String) -> bool:
	return Input.is_action_pressed(action)


func is_action_just_pressed(action: String) -> bool:
	return Input.is_action_just_pressed(action)


func is_action_just_released(action: String) -> bool:
	return Input.is_action_just_pressed(action)
