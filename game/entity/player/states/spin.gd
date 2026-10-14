class_name SpinState
extends PlayerState

## Hitbox enabled during the fast part of the spin.
@export var hitbox: HitBox
@export_group("Rise")
## Upward speed set when spinning while falling.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var rise_from_fall_speed: float = 35.0
## Upward speed added when spinning while rising.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var rise_boost: float = 50.0
## Time gravity is suspended after an airborne spin starts.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var gravity_suspend_time: float = 0.1
@export_group("Timing")
## Length of the fast spin before the slow loop takes over.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var fast_time: float = 0.5
## Minimum spin length before releasing spin can end it.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var active_time: float = 0.5
## How long a jump press stays valid for jumping out of a grounded spin.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var jump_buffer: float = 0.25
@export_group("Animation")
## Animation speed over the fast spin, sampled across its domain.
@export var speed_curve: Curve
## Animation played once the fast spin ends.
@export var slow_animation: StringName = &"spin_loop"

var _suspended: bool = false
var _slowed: bool = false


func _enter() -> void:
	_slowed = false
	_suspended = gravity_suspend_time > 0.0 and not player.is_on_floor()
	hitbox.enable(fast_time)
	sprite.speed_scale = _get_speed_scale()
	if player.is_on_floor():
		return
	
	if player.velocity.y > 0.0:
		player.velocity.y = -rise_from_fall_speed
	else:
		player.velocity.y -= rise_boost


func _tick(_delta: float) -> void:
	if not _slowed:
		sprite.speed_scale = _get_speed_scale()
		if time >= fast_time:
			_slowed = true
			_play_slow_spin()
	
	if _suspended and time >= gravity_suspend_time:
		_suspended = false
	
	if player.is_on_floor():
		player.lock_flipping = false


func _exit() -> void:
	hitbox.disable()


func _next() -> StringName:
	if player.is_on_floor() and controls.is_buffered(&"jump", jump_buffer):
		return &"BaseJump"
	if not controls.is_held(&"spin") and time >= active_time:
		if player.has_landed():
			return &"Idle"
		if player.velocity.y > 0.0:
			return &"Fall"
	if player.can_dive and controls.is_just_pressed(&"dive"):
		return &"Dive"
	return &""


func get_gravity_scale() -> float:
	return 0.0 if _suspended else gravity_scale


func _get_speed_scale() -> float:
	if not speed_curve:
		return 1.0
	
	var ratio: float = clampf(time / fast_time, 0.0, 1.0) if fast_time > 0.0 else 1.0
	return speed_curve.sample(lerpf(speed_curve.min_domain, speed_curve.max_domain, ratio))


func _play_slow_spin() -> void:
	var sprite_frames: SpriteFrames = sprite.diffuse_frames
	var fps: float = sprite.speed_scale * sprite_frames.get_animation_speed(sprite.current_animation)
	sprite.play_at_frame(slow_animation, sprite.current_frame)
	sprite.speed_scale = fps / maxf(sprite_frames.get_animation_speed(slow_animation), 0.001)
