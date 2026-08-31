extends PlayerState


@export var spin_hitbox: HitBox

var _gravity_suspended: bool = false
var _slowed: bool = false


func _enter() -> void:
	player.set_gravity_scale_factor(player.spin_gravity_scale)
	player.is_spinning = true
	spin_hitbox.enable(player.spin_fast_duration)
	_gravity_suspended = false
	_slowed = false
	sprite.speed_scale = player.get_spin_speed_scale(0.0)
	
	if not player.is_on_floor():
		player.set_gravity_enabled(false)
		_gravity_suspended = true
		if player.velocity.y > 0:
			player.velocity.y = player.spin_rise_from_fall
		else:
			player.velocity.y -= player.spin_rise_boost


func _tick(_delta: float) -> void:
	if not _slowed:
		sprite.speed_scale = player.get_spin_speed_scale(time)
		if time >= player.spin_fast_duration:
			_slowed = true
			player.enter_slow_spin()
	
	if _gravity_suspended and time >= player.spin_gravity_resume_time:
		_gravity_suspended = false
		player.set_gravity_enabled(true)
	
	if player.is_spinning and time >= player.spin_duration:
		player.is_spinning = false
	
	if player.is_on_floor():
		player.lock_flipping = false
	
	player.velocity.y = min(player.velocity.y, player.spin_fall_cap)


func _exit() -> void:
	player.set_gravity_enabled(true)
	player.set_gravity_scale_factor(1.0)
	spin_hitbox.disable()


func _next() -> StringName:
	if player.is_on_floor() and player.is_action_just_pressed("jump", player.jump_buffer_window):
		return &"BaseJump"
	if not player.is_input_spin and not player.is_spinning:
		if player.is_on_floor():
			return &"Idle"
		if player.velocity.y > 0.0:
			return &"Fall"
	if player.is_action_just_pressed("dive") and player.can_dive:
		return &"Dive"
	return &""
