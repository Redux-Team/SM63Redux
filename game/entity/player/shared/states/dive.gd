@tool
extends State


@export var target_speed: float = 1250.0
@export var time_to_target_speed: float = 0.058
@export var launch_y_boost: float = 90.0
@export var neutral_launch_y_cap: float = -180.0
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
var was_grounded_last_frame: bool = false
var just_landed: bool = false
var landing_timer: float = 0.0
var body_rotation: float = 0.0
var air_rotation_timer: float = 0.0
var rotation_time_offset: float = 0.0
var from_state: StringName = ""


func _on_enter() -> void:
	player.current_jump = 0
	player.is_diving = true
	player.lock_flipping = true
	player.is_falling = false
	from_state = get_last_state().get_internal_name()
	dive_timer = 0.0
	dive_resetting = false
	dive_reset_timer = 0.0
	just_landed = false
	landing_timer = 0.0
	air_rotation_timer = 0.0
	was_grounded_last_frame = player.is_on_floor()
	gp_conversion_timer = gp_conversion_window if not player.is_on_floor() else 0.0
	
	apply_dive_impulse()
	rotation_time_offset = get_rotation_time_offset_from_velocity(player.velocity.y)
	body_rotation = get_air_rotation_angle() if not player.is_on_floor() else get_slope_angle()
	player.sprite.local_rotation = rad_to_deg(body_rotation)


func _on_exit() -> void:
	player.is_diving = false
	player.lock_flipping = false
	player.sprite.local_rotation = 0.0


func _on_physics_tick(delta: float) -> void:
	dive_timer += delta
	
	if gp_conversion_timer > 0.0:
		gp_conversion_timer -= delta
	
	detect_landing()
	
	if dive_resetting:
		update_dive_reset(delta)
		return
	
	player.get_fludd_handler().set_dive_rotation(body_rotation, PlayerFluddHandler.FluddContext.DIVE)
	
	if player.is_on_floor():
		apply_ground_dive_physics(delta)
	else:
		apply_air_dive_physics(delta)



func _on_tick(delta: float) -> void:
	update_dive_rotation(delta)


func _sprite_rules() -> void:
	if not dive_resetting:
		player.sprite.local_rotation = rad_to_deg(body_rotation)


func apply_dive_impulse() -> void:
	var facing: int = -1 if player.sprite.flip_h else 1
	var current_speed: float = abs(player.velocity.x)
	
	if sign(player.velocity.x) != facing:
		player.velocity.x = 0.0
	
	var speed_difference: float = target_speed - current_speed
	player.velocity.x += (speed_difference / (time_to_target_speed * 60.0)) * facing
	
	if from_state == "idle":
		player.velocity.y = max(neutral_launch_y_cap, player.velocity.y + launch_y_boost)
	else:
		player.velocity.y += launch_y_boost
	
	player.velocity.y = clamp(player.velocity.y, launch_y_min, launch_y_max)
	
	if player.is_on_floor() and player.floor_slope_raycast and player.floor_slope_raycast.is_colliding():
		body_rotation = get_slope_angle()


func apply_ground_dive_physics(delta: float) -> void:
	apply_ground_friction(delta)
	
	if abs(player.velocity.x) < slide_stop_threshold and not Input.is_action_pressed("dive"):
		begin_dive_reset()


func apply_ground_friction(delta: float) -> void:
	var friction_multiplier: float = landing_friction_multiplier if just_landed else 1.0
	just_landed = false
	
	var velocity_sign: float = sign(player.velocity.x)
	var speed: float = abs(player.velocity.x)
	speed = max(0.0, speed - ground_flat_decel * friction_multiplier * delta * 60.0)
	speed = max(0.0, speed - speed * ground_proportional_decel * friction_multiplier)
	player.velocity.x = speed * velocity_sign


func apply_air_dive_physics(delta: float) -> void:
	if abs(player.move_dir) > 0.0:
		apply_dive_air_control(delta)
	
	player.velocity.x *= (1.0 - air_resistance)


func apply_dive_air_control(delta: float) -> void:
	var max_speed: float = player.run_max_speed
	var dive_accel: float = player.walk_acceleration * air_control_multiplier
	var vx: float = player.velocity.x
	var dir: float = player.move_dir
	
	if abs(vx) < max_speed or sign(vx) != sign(dir):
		vx = move_toward(vx, max_speed * dir, dive_accel * delta * 60.0)
	else:
		vx = move_toward(vx, max_speed * sign(vx), dive_accel * delta * 3.0)
	
	player.velocity.x = vx


func get_air_rotation_angle() -> float:
	var rotation_curve_min: float = rotation_curve.min_domain if rotation_curve else 0.0
	var rotation_curve_max: float = rotation_curve.max_domain if rotation_curve else 1.0
	
	var rotation_time: float = clamp(rotation_time_offset + air_rotation_timer, rotation_curve_min, rotation_curve_max)
	
	var curve_value: float
	if rotation_curve:
		curve_value = rotation_curve.sample(rotation_time)
	else:
		curve_value = inverse_lerp(rotation_curve_min, rotation_curve_max, rotation_time)
	
	return deg_to_rad(lerp(90.0, 180.0, curve_value))


func update_dive_rotation(delta: float) -> void:
	if dive_resetting:
		return
	
	if player.is_on_floor():
		air_rotation_timer = 0.0
		landing_timer += delta
		
		var target_angle: float
		if player.floor_slope_raycast and player.floor_slope_raycast.is_colliding():
			target_angle = get_slope_angle()
		else:
			target_angle = deg_to_rad(grounded_angle_deg)
		
		var lerp_speed: float = ground_rotation_blend if landing_timer < landing_rotation_smooth_duration else ground_rotation_blend_fast
		body_rotation = lerp_angle(body_rotation, target_angle, lerp_speed)
	else:
		landing_timer = 0.0
		body_rotation = get_air_rotation_angle()
		air_rotation_timer += delta
	
	player.sprite.local_rotation = rad_to_deg(body_rotation)


func get_slope_angle() -> float:
	if not player.floor_slope_raycast or not player.floor_slope_raycast.is_colliding():
		return deg_to_rad(grounded_angle_deg)
	
	var normal: Vector2 = player.floor_slope_raycast.get_collision_normal()
	return normal.angle() + PI / 2.0


func begin_dive_reset() -> void:
	dive_resetting = true
	dive_reset_timer = 0.0


func update_dive_reset(delta: float) -> void:
	dive_reset_timer += delta
	var progress: float = dive_reset_timer / slide_stop_duration
	
	if progress >= 1.0:
		dive_resetting = false
		player.sprite.local_rotation = 0.0
		return
	
	var facing: int = -1 if player.sprite.flip_h else 1
	body_rotation = -progress * (PI / 2.0) * float(facing)
	
	if progress >= 0.5:
		body_rotation += (PI / 2.0) * float(facing)
	
	player.sprite.local_rotation = rad_to_deg(body_rotation)
	player.velocity.x = move_toward(player.velocity.x, 0.0, 5.0)


func try_convert_to_ground_pound() -> bool:
	if gp_conversion_timer <= 0.0 or player.is_on_floor():
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
	just_landed = is_grounded and not was_grounded_last_frame
	
	if just_landed:
		landing_timer = 0.0
	
	was_grounded_last_frame = is_grounded


func get_rotation_time_offset_from_velocity(y_vel: float) -> float:
	var clamped_y: float
	if y_velocity_to_rotation_offset_curve:
		clamped_y = clamp(y_vel, y_velocity_to_rotation_offset_curve.min_domain, y_velocity_to_rotation_offset_curve.max_domain)
		return y_velocity_to_rotation_offset_curve.sample(clamped_y)
	
	clamped_y = clamp(y_vel, y_velocity_curve_min, y_velocity_curve_max)
	return inverse_lerp(y_velocity_curve_min, y_velocity_curve_max, clamped_y) * rotation_curve.max_domain
