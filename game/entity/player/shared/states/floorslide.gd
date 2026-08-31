extends PlayerState


var body_rotation: float = 0.0
var entered_from_dive: bool = false
var time_since_grounded: float = 0.0
var last_slope_angle: float = 0.0


func _enter() -> void:
	player.lock_flipping = true
	player.set_friction_scale_factor(player.slide_friction_scale)
	entered_from_dive = machine.get_last_state() != null and machine.get_last_state().name == &"Dive"
	time_since_grounded = 0.0
	
	if entered_from_dive:
		body_rotation = deg_to_rad(player.sprite.rotation_degrees)
	elif player.floor_slope_raycast and player.floor_slope_raycast.is_colliding():
		body_rotation = get_slope_angle()
	else:
		body_rotation = deg_to_rad(player.slide_flat_angle)
	
	last_slope_angle = body_rotation


func _next() -> StringName:
	if player.is_action_just_pressed("jump", player.jump_buffer_window) and player.is_on_floor() and player.is_moving_against_facing():
		return &"Backflip"
	if player.is_action_pressed("jump") and player.is_on_floor() and player.get_facing_velocity() > player.slide_rollout_min_speed:
		return &"RolloutF"
	if not player.is_crouching and absf(player.velocity.x) <= player.slide_exit_speed:
		return &"Idle"
	return &""


func _exit() -> void:
	player.lock_flipping = false
	player.set_friction_scale_factor(1.0)
	body_rotation = 0.0
	player.sprite.rotation_degrees = 0.0
	player.get_fludd_handler().set_dive_rotation(body_rotation, PlayerFluddHandler.FluddContext.NONE)


func _tick(delta: float) -> void:
	player.get_fludd_handler().set_dive_rotation(body_rotation, PlayerFluddHandler.FluddContext.FLOOR_SLIDE)
	
	if player.is_on_floor():
		time_since_grounded = 0.0
	else:
		player.velocity.y += player.slide_air_gravity_add
		time_since_grounded += delta
	
	if not player.is_on_floor():
		var speed: Vector2 = abs(player.velocity)
		var vector: Vector2 = sign(player.velocity)
		player.velocity.x = min(speed.x, player.terminal_velocity_x / player.slide_terminal_x_divisor)
		player.velocity.y = min(speed.y, player.terminal_velocity_y / player.slide_terminal_y_divisor)
		player.velocity *= vector


func _render_tick(_delta: float) -> void:
	update_slide_rotation()


func update_slide_rotation() -> void:
	var is_in_ledge_buffer: bool = time_since_grounded < player.slide_ledge_buffer_time
	
	if player.is_on_floor() and player.floor_slope_raycast and player.floor_slope_raycast.is_colliding():
		var target_angle: float = get_slope_angle()
		last_slope_angle = target_angle
		body_rotation = lerp_angle(body_rotation, target_angle, player.slide_angle_lerp_speed)
	elif is_in_ledge_buffer:
		body_rotation = lerp_angle(body_rotation, last_slope_angle, player.slide_angle_lerp_speed)
	elif not player.is_on_floor():
		var facing: float = -1.0 if player.sprite.flip_h else 1.0
		var nosedive_angle: float = deg_to_rad(player.slide_max_nosedive_angle) * facing
		body_rotation = lerp_angle(body_rotation, nosedive_angle, player.slide_airborne_nosedive_speed)
	else:
		body_rotation = lerp_angle(body_rotation, 0.0, player.slide_angle_lerp_speed)
	
	player.sprite.rotation_degrees = rad_to_deg(body_rotation)


func get_slope_angle() -> float:
	if not player.floor_slope_raycast or not player.floor_slope_raycast.is_colliding():
		return deg_to_rad(player.slide_flat_angle)
	var gc: GravityComponent = player.get_component(GravityComponent)
	var g_angle: float = gc.get_angle() if gc else 0.0
	var normal: Vector2 = player.floor_slope_raycast.get_collision_normal()
	return normal.rotated(-g_angle).angle() + PI / 2.0
