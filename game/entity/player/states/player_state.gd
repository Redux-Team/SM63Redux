class_name PlayerState
extends State

@export_group("Physics")
@export var gravity_scale: float = 1.0
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var max_fall_speed: float = 0.0
@export var air_control: PlayerAirControl

var player: Player
var controls: PlayerInput


func _bind() -> void:
	player = entity as Player
	controls = player.controls


func get_gravity_scale() -> float:
	return gravity_scale


func overrides_vertical() -> bool:
	return false
