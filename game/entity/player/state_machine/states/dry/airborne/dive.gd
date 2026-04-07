class_name DiveState
extends State


@export var target_speed: float = 1250.0
@export var time_to_target_speed: float = 0.058
@export var launch_y_boost: float = 90.0
@export var neutral_launch_y_cap: float = -180.0
@export var backflip_speed_multiplier: float = 2.0
@export var launch_y_min: float = -220
@export var launch_y_max: float = 300.0

@export_group("Ground Pound Conversion")
@export var gp_conversion_window: float = 0.1
@export var gp_redirect_angle_deg: float = 36.0

@export_group("Ground Physics")
@export var ground_flat_decel: float = 6.42
@export var ground_proportional_decel: float = 0.0196
@export var landing_friction_multiplier: float = 2.0
@export var slide_stop_threshold: float = 30.0

@export_group("Air Control")
@export var air_control_multiplier: float = 0.35
@export var air_resistance: float = 0.0

@export_group("Rotation")
@export var air_rotation_blend: float = 0.2
@export var ground_rotation_blend: float = 0.15
@export var ground_rotation_blend_fast: float = 0.3
@export var landing_rotation_smooth_duration: float = 0.3
@export var grounded_angle_deg: float = 90.0
@export var rotation_curve: Curve

@export_group("Rotation Helpers")
@export var y_velocity_to_rotation_offset_curve: Curve
@export var y_velocity_curve_min: float = -300.0
@export var y_velocity_curve_max: float = 300.0

@export_group("Recovery")
@export var slide_stop_duration: float = 0.133
@export var rollout_jump_velocity: float = -214.0


var dive_timer: float = 0.0
var gp_conversion_timer: float = 0.0
var dive_resetting: bool = false
var dive_reset_timer: float = 0.0
var just_landed: bool = false
var was_grounded_last_frame: bool = false
var landing_timer: float = 0.0
var body_rotation: float = 0.0
var air_rotation_timer: float = 0.0
var rotation_time_offset: float = 0.0
var from_state: StringName = ""


func _on_enter(from: StringName) -> void:
	player.current_jump = 0
	player.is_diving = true
	player.lock_flipping = true
	player.is_falling = false
	from_state = from
	dive_timer = 0.0
	dive_resetting = false
	dive_reset_timer = 0.0
	just_landed = false
	body_rotation = 0.0
	air_rotation_timer = 0.0
	rotation_time_offset = get_rotation_time_offset_from_velocity(player.velocity.y)
	
	if not player.is_on_floor():
		gp_conversion_timer = gp_conversion_window
	else:
		gp_conversion_timer = 0.0
	
	apply_dive_impulse()


func _on_exit(_to: StringName) -> void:
	player.is_diving = false
	player.lock_flipping = false
	body_rotation = 0.0
	player.sprite.rotation_degrees = 0.0


func _physics_process(delta: float) -> void:
	dive_timer += delta
	
	if gp_conversion_timer > 0.0:
		gp_conversion_timer -= delta
	
	detect_landing()
	
	if dive_resetting:
		update_dive_reset(delta)
		return
	
	if player.is_on_floor():
		apply_ground_dive_physics(delta)
	else:
		apply_air_dive_physics(delta)


func _process(delta: float) -> void:
	update_dive_rotation(delta)


func apply_dive_impulse() -> void:
	var facing: int = -1 if player.sprite.flip_h else 1
	var current_speed: float = abs(player.velocity.x)
	var accel_multiplier: float = 1.0
	
	if from_state == &"Backflip":
		accel_multiplier = backflip_speed_multiplier
	
	var effective_dir: int
	if sign(player.velocity.x) != facing:
		player.velocity.x = 0.0
		effective_dir = facing
	else:
		effective_dir = facing
	
	var speed_difference: float = target_speed - current_speed
	var acceleration: float = speed_difference / (time_to_target_speed * 60.0)
	player.velocity.x += acceleration * accel_multiplier * effective_dir
	
	if from_state == &"Neutral" or from_state == &"Idle":
		player.velocity.y = max(neutral_launch_y_cap, player.velocity.y + launch_y_boost)
	else:
		player.velocity.y += launch_y_boost
	
	player.velocity.y = clamp(player.velocity.y, launch_y_min, launch_y_max)
	
	if player.is_on_floor() and player.floor_slope_raycast and player.floor_slope_raycast.is_colliding():
		body_rotation = get_slope_angle()


func apply_ground_dive_physics(delta: float) -> void:
	apply_ground_friction(delta)
	
	if abs(player.velocity.x) < slide_stop_threshold and not dive_resetting:
		if not Input.is_action_pressed("dive"):
			begin_dive_reset()


func apply_ground_friction(delta: float) -> void:
	var friction_multiplier: float = 1.0
	
	if just_landed:
		friction_multiplier = landing_friction_multiplier
		just_landed = false
	
	var velocity_sign: float = sign(player.velocity.x)
	var speed: float = abs(player.velocity.x)
	var constant_friction: float = ground_flat_decel * friction_multiplier * delta * 60.0
	speed = max(0.0, speed - constant_friction)
	var factor_friction: float = speed * ground_proportional_decel * friction_multiplier
	speed = max(0.0, speed - factor_friction)
	player.velocity.x = speed * velocity_sign


func apply_air_dive_physics(delta: float) -> void:
	if abs(player.move_dir) > 0.0:
		apply_dive_air_control(delta)
	
	player.velocity.x *= (1.0 - air_resistance)


func apply_dive_air_control(delta: float) -> void:
	var accel: float = player.walk_acceleration
	var max_speed: float = player.run_max_speed
	var dive_accel: float = accel * air_control_multiplier
	var vx: float = player.velocity.x
	var dir: float = player.move_dir
	
	if abs(vx) < max_speed or sign(vx) != sign(dir):
		vx = move_toward(vx, max_speed * dir, dive_accel * delta * 60.0)
	else:
		vx = move_toward(vx, max_speed * sign(vx), dive_accel * delta * 3.0)
	
	player.velocity.x = vx


func clamp_rotation_to_lower_quadrants(angle: float) -> float:
	return angle


func get_air_rotation_angle() -> float:
	var facing: int = -1 if player.sprite.flip_h else 1
	var rotation_curve_min: float = 0.0
	var rotation_curve_max: float = rotation_curve.max_domain
	
	if rotation_curve:
		rotation_curve_min = rotation_curve.min_domain
		rotation_curve_max = rotation_curve.max_domain
	
	var rotation_time: float = rotation_time_offset + air_rotation_timer
	rotation_time = clamp(rotation_time, rotation_curve_min, rotation_curve_max)
	
	var curve_value: float = rotation_time
	if rotation_curve:
		curve_value = rotation_curve.sample(rotation_time)
	else:
		# If no curve provided, map time into 0..1 for linear lerp
		curve_value = inverse_lerp(rotation_curve_min, rotation_curve_max, rotation_time)
	
	var start_angle: float = 90.0
	var end_angle: float = 180.0 if facing > 0 else 0.0
	var current_degrees: float = lerp(start_angle, end_angle, curve_value)
	
	if player.sprite.flip_h:
		current_degrees = 180.0 - current_degrees
	
	return deg_to_rad(current_degrees)


func update_dive_rotation(delta: float) -> void:
	if dive_resetting:
		return
	
	var target_angle: float = 0.0
	var lerp_speed: float = 0.0
	
	if player.is_on_floor():
		air_rotation_timer = 0.0
		
		if player.floor_slope_raycast and player.floor_slope_raycast.is_colliding():
			target_angle = get_slope_angle()
		else:
			target_angle = deg_to_rad(grounded_angle_deg)
		
		landing_timer += delta
		lerp_speed = ground_rotation_blend if landing_timer < landing_rotation_smooth_duration else ground_rotation_blend_fast
		body_rotation = lerp_angle(body_rotation, target_angle, lerp_speed)
	else:
		air_rotation_timer += delta
		landing_timer = 0.0
		target_angle = get_air_rotation_angle()
		body_rotation = target_angle
	
	var visual_angle: float = rad_to_deg(body_rotation)
	if player.sprite.flip_h:
		visual_angle = -visual_angle
	player.sprite.rotation_degrees = visual_angle


func get_slope_angle() -> float:
	if not player.floor_slope_raycast or not player.floor_slope_raycast.is_colliding():
		return deg_to_rad(grounded_angle_deg)
	
	var normal: Vector2 = player.floor_slope_raycast.get_collision_normal()
	return normal.angle() + PI / 2.0


func get_velocity_angle() -> float:
	var vel_angle: float = atan2(player.velocity.y, player.velocity.x)
	var facing: int = -1 if player.sprite.flip_h else 1
	return vel_angle + PI / 2.0 * (1.0 - float(facing))


func begin_dive_reset() -> void:
	dive_resetting = true
	dive_reset_timer = 0.0


func update_dive_reset(delta: float) -> void:
	dive_reset_timer += delta
	var progress: float = dive_reset_timer / slide_stop_duration
	
	if progress >= 1.0:
		dive_resetting = false
		player.sprite.rotation_degrees = 0.0
		return
	
	var facing: int = -1 if player.sprite.flip_h else 1
	body_rotation = -progress * (PI / 2.0) * float(facing)
	
	if progress >= 0.5:
		body_rotation += (PI / 2.0) * float(facing)
	
	player.sprite.rotation_degrees = rad_to_deg(body_rotation)
	player.velocity.x = move_toward(player.velocity.x, 0.0, 5.0)


func try_convert_to_ground_pound() -> bool:
	if gp_conversion_timer <= 0.0:
		return false
	
	if player.is_on_floor():
		return false
	
	var speed: float = player.velocity.length()
	var angle_rad: float = deg_to_rad(gp_redirect_angle_deg)
	
	if player.velocity.x <= 0.0:
		angle_rad = PI - angle_rad
	
	player.velocity = Vector2(cos(angle_rad) * speed, sin(angle_rad) * speed)
	return true


func can_rollout() -> bool:
	return player.is_on_floor() and abs(player.velocity.x) >= slide_stop_threshold and not dive_resetting


func detect_landing() -> void:
	var is_grounded: bool = player.is_on_floor()
	
	if is_grounded and not was_grounded_last_frame:
		just_landed = true
		landing_timer = 0.0
	else:
		just_landed = false
	
	was_grounded_last_frame = is_grounded


func get_rotation_time_offset_from_velocity(y_vel: float) -> float:
	if y_velocity_to_rotation_offset_curve:
		var min_d: float = y_velocity_to_rotation_offset_curve.min_domain
		var max_d: float = y_velocity_to_rotation_offset_curve.max_domain
		var clamped_y: float = clamp(y_vel, min_d, max_d)
		return y_velocity_to_rotation_offset_curve.sample(clamped_y)
	
	# fallback: linear map from configured min/max to 0..rotation_curve.max_domain
	var clamped_y2: float = clamp(y_vel, y_velocity_curve_min, y_velocity_curve_max)
	var norm: float = inverse_lerp(y_velocity_curve_min, y_velocity_curve_max, clamped_y2)
	return norm * rotation_curve.max_domain
