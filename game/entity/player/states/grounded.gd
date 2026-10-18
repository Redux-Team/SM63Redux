extends PlayerState

@export_group("Run")
## Top running speed at full input.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var run_speed: float = 203.5
## Acceleration toward run speed.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s²") var acceleration: float = 1153.8
## Acceleration while running against the current direction.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s²") var turn_acceleration: float = 2307.7
@export_group("Brake")
## Constant deceleration while braking without input.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s²") var brake_deceleration: float = 16.35
## Time for braking alone to halve the player's speed.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var brake_halflife: float = 0.0827
## Floor friction multiplier while braking.
@export var brake_friction_scale: float = 1.39


func _tick(delta: float) -> void:
	var drag: float = player.get_floor_drag_rate()
	if is_zero_approx(player.move_input) or machine.is_active(&"Crouch"):
		player.brake(brake_deceleration, Motion.rate(brake_halflife) + drag * brake_friction_scale, delta)
	else:
		player.drive(player.move_input, player.get_ground_speed(run_speed), player.get_ground_acceleration(acceleration), player.get_ground_acceleration(turn_acceleration), 0.0, drag, delta)
	
	player.velocity.y = 0.0
