class_name PlayerState
extends State

@export_group("Physics")
## Multiplier on the player's gravity while this state is active.
@export var gravity_scale: float = 1.0
## Caps downward speed while this state is active; zero disables the cap.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var max_fall_speed: float = 0.0
## Air steering used while this state is active; inherits the nearest parent's when empty.
@export var air_control: PlayerAirControl

## The player this state drives.
var player: Player
## Shortcut to the player's buffered input.
var controls: PlayerInput


func _bind() -> void:
	player = entity as Player
	controls = player.controls


func get_gravity_scale() -> float:
	return gravity_scale


func overrides_vertical() -> bool:
	return false
