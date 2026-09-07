extends PlayerState


var _body_rotation: float = 0.0
var _time_since_grounded: float = 0.0
var _last_slope_angle: float = 0.0


func _enter() -> void:
	player.lock_flipping = true
	player.set_friction_modifier(&"floorslide", player.slide_friction_scale)
	_time_since_grounded = 0.0
	
	var last_state: State = machine.get_last_state()
	if last_state and last_state.name == &"Dive":
		_body_rotation = deg_to_rad(player.sprite.rotation_degrees)
	elif player.floor_slope_raycast and player.floor_slope_raycast.is_colliding():
		_body_rotation = _get_slope_angle()
	else:
		_body_rotation = deg_to_rad(player.slide_flat_angle)
	
	_last_slope_angle = _body_rotation


func _exit() -> void:
	player.lock_flipping = false
	player.clear_friction_modifier(&"floorslide")
	_body_rotation = 0.0
	player.sprite.rotation_degrees = 0.0
	player.get_fludd_handler().set_dive_rotation(_body_rotation, PlayerFluddHandler.FluddContext.NONE)


func _tick(delta: float) -> void:
	player.get_fludd_handler().set_dive_rotation(_body_rotation, PlayerFluddHandler.FluddContext.FLOOR_SLIDE)
	
	if player.is_on_floor():
		_time_since_grounded = 0.0
		_apply_slope_acceleration()
		return
	
	player.velocity.y += player.slide_air_gravity_add
	_time_since_grounded += delta
	_apply_air_terminal()


func _apply_slope_acceleration() -> void:
	player.velocity.x += player.get_local_floor_normal().x * player.slide_slope_acceleration


func _apply_air_terminal() -> void:
	var terminal_x: float = player.terminal_velocity_x / player.slide_terminal_x_divisor
	var terminal_y: float = player.terminal_velocity_y / player.slide_terminal_y_divisor
	
	player.velocity.x = move_toward(player.velocity.x, clampf(player.velocity.x, -terminal_x, terminal_x), player.slide_terminal_decel)
	player.velocity.y = clampf(player.velocity.y, -terminal_y, terminal_y)


func _render_tick(_delta: float) -> void:
	_update_rotation()


func _next() -> StringName:
	if player.is_action_just_pressed("jump", player.jump_buffer_window) and player.is_on_floor() and player.is_moving_against_facing():
		return &"Backflip"
	if player.is_action_pressed("jump") and player.is_on_floor() and player.get_facing_velocity() > player.slide_rollout_min_speed:
		return &"RolloutF"
	if player.is_on_floor() and absf(player.velocity.x) <= _exit_speed():
		return &"Idle"
	return &""


func _exit_speed() -> float:
	return player.slide_exit_speed if player.is_crouching else player.slide_release_exit_speed


func _update_rotation() -> void:
	if player.is_on_floor() and player.floor_slope_raycast and player.floor_slope_raycast.is_colliding():
		_last_slope_angle = _get_slope_angle()
		_body_rotation = lerp_angle(_body_rotation, _last_slope_angle, player.slide_angle_lerp_speed)
	elif _time_since_grounded < player.slide_ledge_buffer_time:
		_body_rotation = lerp_angle(_body_rotation, _last_slope_angle, player.slide_angle_lerp_speed)
	elif not player.is_on_floor():
		var nosedive_angle: float = deg_to_rad(player.slide_max_nosedive_angle) * float(player.get_facing())
		_body_rotation = lerp_angle(_body_rotation, nosedive_angle, player.slide_airborne_nosedive_speed)
	else:
		_body_rotation = lerp_angle(_body_rotation, 0.0, player.slide_angle_lerp_speed)
	
	player.sprite.rotation_degrees = rad_to_deg(_body_rotation)


func _get_slope_angle() -> float:
	if not player.floor_slope_raycast or not player.floor_slope_raycast.is_colliding():
		return deg_to_rad(player.slide_flat_angle)
	
	var gravity_component: GravityComponent = player.get_component(GravityComponent)
	var gravity_angle: float = gravity_component.get_angle() if gravity_component else 0.0
	var normal: Vector2 = player.floor_slope_raycast.get_collision_normal()
	return normal.rotated(-gravity_angle).angle() + PI / 2.0
