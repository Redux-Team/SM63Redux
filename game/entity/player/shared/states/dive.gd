extends PlayerState


var _previous_state_name: StringName = &""
var _body_rotation: float = 0.0
var _landing_timer: float = 0.0
var _was_grounded: bool = false
var _just_landed: bool = false
var _resetting: bool = false
var _reset_timer: float = 0.0


func _enter() -> void:
	player.jump_chain_index = 0
	player.is_diving = true
	player.lock_flipping = true
	_previous_state_name = machine.get_last_state().name if machine.get_last_state() else &""
	_resetting = false
	_reset_timer = 0.0
	_just_landed = false
	_landing_timer = 0.0
	_was_grounded = player.is_on_floor()
	
	_apply_impulse()
	_body_rotation = _get_air_rotation_angle() if not player.is_on_floor() else _get_slope_angle()
	player.sprite.local_rotation = rad_to_deg(_body_rotation)


func _exit() -> void:
	player.cancel_stomp()
	player.is_diving = false
	player.lock_flipping = false
	player.sprite.local_rotation = 0.0


func _tick(delta: float) -> void:
	player.tick_stomp(delta)
	_detect_landing()
	
	if _resetting:
		_update_reset(delta)
		return
	
	player.get_fludd_handler().set_dive_rotation(_body_rotation, PlayerFluddHandler.FluddContext.DIVE)
	
	if player.is_on_floor():
		_apply_ground_physics(delta)
	else:
		_apply_air_physics(delta)


func _render_tick(delta: float) -> void:
	if not _resetting:
		player.sprite.local_rotation = rad_to_deg(_body_rotation)
	_update_rotation(delta)


func _next() -> StringName:
	return &"Floorslide" if player.is_on_floor() else &""


func _apply_impulse() -> void:
	var facing: int = player.get_facing()
	var current_speed: float = abs(player.velocity.x)
	
	if sign(player.velocity.x) != facing:
		player.velocity.x = 0.0
	
	var speed_difference: float = player.dive_target_speed - current_speed
	player.velocity.x += (speed_difference / (player.dive_time_to_target_speed * 60.0)) * facing
	
	if _previous_state_name == &"Idle":
		player.velocity.y = max(player.dive_neutral_launch_y_cap, player.velocity.y + player.dive_launch_y_boost)
	else:
		player.velocity.y += player.dive_launch_y_boost
	
	player.velocity.y = clamp(player.velocity.y, player.dive_launch_y_min, player.dive_launch_y_max)
	
	if player.is_on_floor() and player.floor_slope_raycast and player.floor_slope_raycast.is_colliding():
		_body_rotation = _get_slope_angle()


func _apply_ground_physics(delta: float) -> void:
	_apply_ground_friction(delta)
	
	if abs(player.velocity.x) < player.dive_slide_stop_threshold and not player.is_action_pressed("dive"):
		_resetting = true
		_reset_timer = 0.0


func _apply_ground_friction(delta: float) -> void:
	var friction_multiplier: float = player.dive_landing_friction_multiplier if _just_landed else 1.0
	_just_landed = false
	
	var velocity_sign: float = sign(player.velocity.x)
	var speed: float = abs(player.velocity.x)
	speed = max(0.0, speed - player.dive_ground_flat_decel * friction_multiplier * delta * 60.0)
	speed = max(0.0, speed - speed * player.dive_ground_proportional_decel * friction_multiplier)
	player.velocity.x = speed * velocity_sign


func _apply_air_physics(delta: float) -> void:
	if abs(player.move_input) > 0.0:
		_apply_air_control(delta)
	
	player.velocity.x *= (1.0 - player.dive_air_resistance)


func _apply_air_control(delta: float) -> void:
	var max_speed: float = player.run_max_speed
	var acceleration: float = player.walk_acceleration * player.dive_air_control
	var speed_x: float = player.velocity.x
	var move_input: float = player.move_input
	
	if abs(speed_x) < max_speed or sign(speed_x) != sign(move_input):
		speed_x = move_toward(speed_x, max_speed * move_input, acceleration * delta * 60.0)
	else:
		speed_x = move_toward(speed_x, max_speed * sign(speed_x), acceleration * delta * player.dive_over_speed_decel)
	
	player.velocity.x = speed_x


func _detect_landing() -> void:
	var is_grounded: bool = player.is_on_floor()
	_just_landed = is_grounded and not _was_grounded
	
	if _just_landed:
		_landing_timer = 0.0
	
	_was_grounded = is_grounded


func _update_rotation(delta: float) -> void:
	if _resetting:
		return
	
	if player.is_on_floor():
		_landing_timer += delta
		
		var target_angle: float
		if player.floor_slope_raycast and player.floor_slope_raycast.is_colliding():
			target_angle = _get_slope_angle()
		else:
			target_angle = deg_to_rad(player.dive_grounded_angle_deg)
		
		var lerp_speed: float = player.dive_ground_rotation_blend if _landing_timer < player.dive_landing_rotation_smooth_duration else player.dive_ground_rotation_blend_fast
		_body_rotation = lerp_angle(_body_rotation, target_angle, lerp_speed)
	else:
		_landing_timer = 0.0
		_body_rotation = lerp_angle(_body_rotation, _get_air_rotation_angle(), player.dive_air_rotation_blend)
	
	player.sprite.local_rotation = rad_to_deg(_body_rotation)


func _update_reset(delta: float) -> void:
	_reset_timer += delta
	var progress: float = _reset_timer / player.dive_slide_stop_duration
	
	if progress >= 1.0:
		_resetting = false
		player.sprite.local_rotation = 0.0
		return
	
	var facing: float = float(player.get_facing())
	_body_rotation = -progress * (PI / 2.0) * facing
	
	if progress >= 0.5:
		_body_rotation += (PI / 2.0) * facing
	
	player.sprite.local_rotation = rad_to_deg(_body_rotation)
	player.velocity.x = move_toward(player.velocity.x, 0.0, player.dive_reset_decel)


## The dive angle tracks the velocity vector rather than a timed curve, so the body points where the
## player is actually travelling.
func _get_air_rotation_angle() -> float:
	var facing: float = -1.0 if player.sprite.flip_h else 1.0
	var heading: float = rad_to_deg(Vector2(player.velocity.x * facing, player.velocity.y).angle())
	
	return deg_to_rad(clamp(heading, player.dive_rotation_min_deg, player.dive_rotation_max_deg))


func _get_slope_angle() -> float:
	if not player.floor_slope_raycast or not player.floor_slope_raycast.is_colliding():
		return deg_to_rad(player.dive_grounded_angle_deg)
	
	var normal: Vector2 = player.floor_slope_raycast.get_collision_normal()
	return normal.angle() + PI / 2.0
