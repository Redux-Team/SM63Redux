extends PlayerState

## Hitbox that strikes enemies while sliding fast enough.
@export var hitbox: HitBox

const FRICTION_KEY: StringName = &"floorslide"

@export_group("Ground")
## Floor friction multiplier applied for the duration of the slide.
@export var friction_scale: float = 1.6
## Acceleration along downhill slopes, scaled by the slope's steepness.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s²") var slope_acceleration: float = 720.0
@export_group("Air")
## Additional gravity multiplier after sliding off a ledge.
@export var air_gravity_scale: float = 1.0667
## Horizontal speed the slide decelerates toward while airborne.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var max_air_speed: float = 250.0
## Deceleration toward max air speed while airborne.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s²") var air_speed_deceleration: float = 480.0
## Caps upward speed while airborne.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var max_rise_speed: float = 483.33
@export_group("Exits")
## Speed below which the slide ends while crouch is held.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var crouch_exit_speed: float = 5.0
## Speed below which the slide ends once crouch is released.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var exit_speed: float = 150.0
@export var slope_exit_margin: float = 1.1
## Forward speed needed to roll out with a jump.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var rollout_min_speed: float = 50.0
## How long a jump press stays valid for a backflip.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var jump_buffer: float = 0.25
## Time airborne before the slide turns into a glide when gliding is available.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var glide_delay: float = 0.1
@export_group("Rotation")
## Body angle used when no slope is detected.
@export_range(-180.0, 180.0, 0.1, "degrees") var flat_angle: float = 90.0
## Body angle tipped toward after leaving a ledge.
@export_range(-180.0, 180.0, 0.1, "degrees") var nosedive_angle: float = 45.0
## Time for the body to turn halfway toward the slope angle.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var rotation_halflife: float = 0.0167
## Time for the body to turn halfway toward the nosedive angle.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var nosedive_halflife: float = 0.0711
## Time after leaving the floor before the body starts to nosedive.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var ledge_buffer: float = 0.15

var _body_rotation: float = 0.0
var _slope_angle: float = 0.0
var _airborne_time: float = 0.0


func _enter() -> void:
	hitbox.enable()
	player.lock_flipping = true
	player.friction_modifiers.set_modifier(FRICTION_KEY, friction_scale)
	_airborne_time = 0.0
	_body_rotation = player.get_slope_angle(deg_to_rad(flat_angle))
	_slope_angle = _body_rotation
	player.fludd.set_body_rotation(_body_rotation, PlayerFludd.Context.FLOOR_SLIDE)


func _exit() -> void:
	hitbox.disable()
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
	if not grounded and _airborne_time > glide_delay and player.can_glide():
		return &"Glide"
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
	if not player.is_crouching():
		return exit_speed
	
	var settle_speed: float = absf(player.get_floor_normal().x) * slope_acceleration / player.get_floor_drag_rate()
	return maxf(crouch_exit_speed, settle_speed * slope_exit_margin)
