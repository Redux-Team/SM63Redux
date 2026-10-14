class_name SubmergedState
extends PlayerState

@export_group("Swim")
## Top horizontal swim speed before water resistance.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var swim_speed: float = 220.0
## Multiplier on swim speed underwater.
@export_range(0.0, 1.0) var water_resistance: float = 0.6
## Horizontal swim acceleration.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s²") var acceleration: float = 720.0
## Horizontal swim acceleration while reversing direction.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s²") var turn_acceleration: float = 849.6
## Minimum opposing speed before turn acceleration is used.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var turn_speed_threshold: float = 10.0
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var overspeed_halflife: float = 0.12
@export_group("Vertical")
## Upward speed steered toward while holding swim up.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var rise_speed: float = 140.0
## Downward speed steered toward while holding swim down.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var sink_speed: float = 140.0
## Time for vertical steering to close half the gap to its target speed.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var steer_halflife: float = 0.0518
## Downward speed drifted toward without vertical input.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var drift_speed: float = 20.0
## Time for the drift to close half the gap to the drift speed.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var drift_halflife: float = 0.1096
## Minimum downward speed kept on slopes so the player hugs the floor.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var slope_speed: float = 3.0
@export_group("Exit")
## Multiplier on upward speed when leaving the water.
@export var exit_boost: float = 2.5
## Caps the upward speed from the exit boost.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var max_exit_speed: float = 300.0


func _tick(delta: float) -> void:
	_swim(delta)
	if not (machine.get_state() as PlayerState).overrides_vertical():
		_drift(delta)
	
	if not player.is_on_floor() and controls.is_held(&"ground_pound") and player.can_ground_pound:
		machine.change_state(&"GroundPoundStart")


func _exit() -> void:
	if player.velocity.y < 0.0:
		player.velocity.y = maxf(player.velocity.y * exit_boost, -max_exit_speed)


func _next() -> StringName:
	if not player.is_in_water():
		return &"Fall" if player.velocity.y > 0.0 else &"IdleJump"
	return &"SwimIdle" if is_current() else &""


func _swim(delta: float) -> void:
	var input: float = player.move_input
	var floor_drag: float = player.get_floor_drag_rate() if player.is_on_floor() else 0.0
	if is_zero_approx(input) or not player.can_walk:
		player.velocity.x = Motion.drift(player.velocity.x, 0.0, player.get_floor_drag_rate() + floor_drag, delta)
	elif not player.is_crouching():
		player.drive(input, player.get_ground_speed(swim_speed) * water_resistance, acceleration, turn_acceleration, turn_speed_threshold, floor_drag, delta)
	
	var cap: float = player.get_ground_speed(swim_speed) * water_resistance
	if absf(player.velocity.x) > cap:
		player.velocity.x = maxf(Motion.drift(absf(player.velocity.x), 0.0, Motion.rate(overspeed_halflife), delta), cap) * signf(player.velocity.x)
	
	if player.is_on_floor() and player.get_floor_normal().y < 0.999 and player.velocity.y >= 0.0:
		player.velocity.y = maxf(player.velocity.y, slope_speed)


func _drift(delta: float) -> void:
	if player.fludd.is_aiming():
		return
	
	if player.fludd.is_spraying() or is_zero_approx(controls.swim):
		player.velocity.y = Motion.damp(player.velocity.y, drift_speed, drift_halflife, delta)
	elif controls.swim < 0.0:
		player.velocity.y = Motion.damp(player.velocity.y, -rise_speed, steer_halflife, delta)
	else:
		player.velocity.y = Motion.damp(player.velocity.y, sink_speed, steer_halflife, delta)
