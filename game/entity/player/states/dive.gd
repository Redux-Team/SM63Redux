class_name DiveState
extends PlayerState

## Hitbox that strikes enemies while diving fast enough.
@export var hitbox: HitBox

@export_group("Launch")
## Horizontal speed the dive launch pulls toward.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var target_speed: float = 900.0
## Fraction of the gap to target speed added on launch.
@export_range(0.0, 1.0) var launch_strength: float = 0.2874
## Downward speed added on launch.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var vertical_boost: float = 40.0
## Caps upward speed when diving straight out of an idle state.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var standing_max_rise_speed: float = 172.5
## Caps upward speed on launch.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var max_rise_speed: float = 592.5
## Caps downward speed on launch.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var max_drop_speed: float = 307.5
@export_group("Landing")
## Horizontal speed removed when the dive touches the floor.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var landing_speed_loss: float = 12.84
## Fraction of horizontal speed kept after the landing loss.
@export_range(0.0, 1.0) var landing_speed_retention: float = 0.8887
@export_group("Stomp")
## Time gravity is suspended after the feet land on an enemy mid-dive.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var stomp_duration: float = 0.15
## Upward speed set once the mid-dive stomp ends.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var stomp_bounce_speed: float = 272.5
@export_group("Rotation")
## Time for the body to turn halfway toward its target angle.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var rotation_halflife: float = 0.0518
## Most upward body angle while airborne.
@export_range(-180.0, 180.0, 0.1, "degrees") var min_angle: float = -60.0
## Most downward body angle while airborne.
@export_range(-180.0, 180.0, 0.1, "degrees") var max_angle: float = 85.0
## Body angle used on the floor when no slope is detected.
@export_range(-180.0, 180.0, 0.1, "degrees") var floor_angle: float = 90.0

var _body_rotation: float = 0.0
var _stomp_time: float = 0.0
var _was_grounded: bool = false


func _enter() -> void:
	player.jump_chain = 0
	player.lock_flipping = true
	hitbox.enable()
	_stomp_time = 0.0
	_was_grounded = player.is_on_floor()
	_launch()
	_body_rotation = player.get_slope_angle(deg_to_rad(floor_angle)) if _was_grounded else _get_heading()
	sprite.local_rotation = rad_to_deg(_body_rotation)
	player.fludd.set_body_rotation(_body_rotation, PlayerFludd.Context.DIVE)


func _exit() -> void:
	hitbox.disable()
	_stomp_time = 0.0
	player.lock_flipping = false
	sprite.local_rotation = 0.0


func _tick(delta: float) -> void:
	_tick_stomp(delta)
	if player.is_on_floor() and not _was_grounded:
		_land()
	
	_was_grounded = player.is_on_floor()
	_rotate(delta)
	player.fludd.set_body_rotation(_body_rotation, PlayerFludd.Context.DIVE)


func _land() -> void:
	var speed: float = maxf(absf(player.velocity.x) - landing_speed_loss, 0.0) * landing_speed_retention
	player.velocity.x = speed * signf(player.velocity.x)
	_body_rotation = player.get_slope_angle(deg_to_rad(floor_angle))
	sprite.local_rotation = rad_to_deg(_body_rotation)


func _rotate(delta: float) -> void:
	var target: float = player.get_slope_angle(deg_to_rad(floor_angle)) if player.is_on_floor() else _get_heading()
	_body_rotation = Motion.damp_angle(_body_rotation, target, rotation_halflife, delta)
	sprite.local_rotation = rad_to_deg(_body_rotation)


func _next() -> StringName:
	if player.is_on_floor():
		return &"Floorslide"
	return &"Glide" if player.can_glide() else &""


func get_gravity_scale() -> float:
	return 0.0 if _stomp_time > 0.0 else gravity_scale


func stomp() -> void:
	if _stomp_time > 0.0:
		return
	
	_stomp_time = stomp_duration
	player.velocity.y = minf(player.velocity.y, 0.0)


func _tick_stomp(delta: float) -> void:
	if _stomp_time <= 0.0:
		return
	
	_stomp_time -= delta
	if _stomp_time <= 0.0:
		player.velocity.y = -player.get_jump_speed(stomp_bounce_speed)


func _launch() -> void:
	var facing: float = float(player.get_facing())
	var speed: float = absf(player.velocity.x)
	if signf(player.velocity.x) != facing:
		player.velocity.x = 0.0
	
	player.velocity.x += (target_speed - speed) * launch_strength * facing
	player.velocity.y += vertical_boost
	if machine.get_last_state() and machine.get_last_state().name == &"Idle":
		player.velocity.y = maxf(player.velocity.y, -standing_max_rise_speed)
	
	player.velocity.y = maxf(player.velocity.y, -max_rise_speed) if player.dive_keeps_fall_speed() else clampf(player.velocity.y, -max_rise_speed, max_drop_speed)


func _get_heading() -> float:
	var heading: float = rad_to_deg(Vector2(player.velocity.x * player.get_facing(), player.velocity.y).angle())
	return deg_to_rad(clampf(heading, min_angle, max_angle))
