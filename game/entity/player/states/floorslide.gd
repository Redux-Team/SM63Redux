extends PlayerState

const FRICTION_KEY: StringName = &"floorslide"

@export_group("Ground")
@export var friction_scale: float = 1.6
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s²") var slope_acceleration: float = 720.0
@export_group("Air")
@export var air_gravity_scale: float = 1.0667
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var max_air_speed: float = 250.0
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s²") var air_speed_deceleration: float = 480.0
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var max_rise_speed: float = 483.33
@export_group("Exits")
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var crouch_exit_speed: float = 5.0
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var exit_speed: float = 150.0
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var rollout_min_speed: float = 50.0
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var jump_buffer: float = 0.2
@export_group("Rotation")
@export_range(-180.0, 180.0, 0.1, "degrees") var flat_angle: float = 90.0
@export_range(-180.0, 180.0, 0.1, "degrees") var nosedive_angle: float = 45.0
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var rotation_halflife: float = 0.0167
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var nosedive_halflife: float = 0.0711
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var ledge_buffer: float = 0.15

var _body_rotation: float = 0.0
var _slope_angle: float = 0.0
var _airborne_time: float = 0.0


func _enter() -> void:
	player.lock_flipping = true
	player.friction_modifiers.set_modifier(FRICTION_KEY, friction_scale)
	_airborne_time = 0.0
	_body_rotation = player.get_slope_angle(deg_to_rad(flat_angle))
	_slope_angle = _body_rotation
	player.fludd.set_body_rotation(_body_rotation, PlayerFludd.Context.FLOOR_SLIDE)


func _exit() -> void:
	player.lock_flipping = false
	player.friction_modifiers.clear_modifier(FRICTION_KEY)
	sprite.rotation_degrees = 0.0
	player.fludd.set_body_rotation(0.0, PlayerFludd.Context.NONE)


func _tick(delta: float) -> void:
	_rotate(delta)
	player.fludd.set_body_rotation(_body_rotation, PlayerFludd.Context.FLOOR_SLIDE)
	if player.is_on_floor():
		_airborne_time = 0.0
		player.velocity.x = Motion.drift(player.velocity.x, player.get_floor_normal().x * slope_acceleration, player.get_floor_drag_rate(), delta)
		return
	
	_airborne_time += delta
	player.velocity.x = Motion.approach(player.velocity.x, clampf(player.velocity.x, -max_air_speed, max_air_speed), air_speed_deceleration, delta)
	player.velocity.y = maxf(player.velocity.y, -max_rise_speed)


func _rotate(delta: float) -> void:
	if player.is_on_floor() and player.floor_raycast.is_colliding():
		_slope_angle = player.get_slope_angle(deg_to_rad(flat_angle))
		_body_rotation = Motion.damp_angle(_body_rotation, _slope_angle, rotation_halflife, delta)
	elif _airborne_time < ledge_buffer:
		_body_rotation = Motion.damp_angle(_body_rotation, _slope_angle, rotation_halflife, delta)
	elif not player.is_on_floor():
		_body_rotation = Motion.damp_angle(_body_rotation, deg_to_rad(nosedive_angle) * player.get_facing(), nosedive_halflife, delta)
	else:
		_body_rotation = Motion.damp_angle(_body_rotation, 0.0, rotation_halflife, delta)
	
	sprite.rotation_degrees = rad_to_deg(_body_rotation)


func _next() -> StringName:
	var grounded: bool = player.is_on_floor()
	if grounded and player.is_moving_against_facing() and controls.is_buffered(&"jump", jump_buffer):
		return &"Backflip"
	if grounded and controls.is_held(&"jump") and player.get_facing_velocity() > rollout_min_speed:
		return &"RolloutF"
	if grounded and absf(player.velocity.x) <= _get_exit_speed() and not player.fludd.is_committing():
		return &"Idle"
	return &""


func get_gravity_scale() -> float:
	return gravity_scale if player.is_on_floor() else gravity_scale * air_gravity_scale


func _get_exit_speed() -> float:
	return crouch_exit_speed if player.is_crouching() else exit_speed
