class_name DiveState
extends State

@export var dive_target_speed: float = 500.0
@export var dive_accel_time: float = 0.083
@export var dive_y_boost: float = 96.0
@export var dive_y_cap_neutral: float = -180.0
@export var backflip_accel_mult: float = 2.0

@export_group("Ground Pound Conversion")
@export var gp_dive_window_time: float = 0.1
@export var gp_dive_angle_deg: float = 36.0

@export_group("Ground Physics")
@export var dive_friction_constant: float = 6.42
@export var dive_friction_factor: float = 0.0196
@export var dive_landing_friction_mult: float = 2.0

@export_group("Air Control")
@export var dive_air_control_mult: float = 0.35
@export var dive_air_resistance: float = 0.0

@export_group("Rotation")
@export var dive_angle_lerp_air: float = 0.2
@export var dive_angle_lerp_ground: float = 0.15
@export var dive_angle_lerp_ground_fast: float = 0.3
@export var dive_landing_smooth_time: float = 0.3
@export var dive_flat_angle: float = 90.0

@export_group("Recovery")
@export var dive_reset_time: float = 0.133
@export var rollout_jump_vel: float = -214.0
@export var crouch_speed_threshold: float = 30.0

var dive_timer: float = 0.0
var gp_conversion_timer: float = 0.0
var dive_resetting: bool = false
var dive_reset_timer: float = 0.0
var just_landed: bool = false
var was_grounded_last_frame: bool = false
var landing_timer: float = 0.0
var body_rotation: float = 0.0
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
	
	if not player.is_on_floor():
		gp_conversion_timer = gp_dive_window_time
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
	var current_speed: float = abs(player.velocity.x)
	var speed_difference: float = dive_target_speed - current_speed
	var acceleration: float = speed_difference / (dive_accel_time * 60.0)
	var accel_multiplier: float = 1.0
	
	if from_state == &"Backflip":
		accel_multiplier = backflip_accel_mult
	
	var facing: int = -1 if player.sprite.flip_h else 1
	player.velocity.x += acceleration * accel_multiplier * facing
	
	if from_state == &"Neutral" or from_state == &"Idle":
		player.velocity.y = max(dive_y_cap_neutral, player.velocity.y + dive_y_boost)
	else:
		player.velocity.y += dive_y_boost
	
	if player.is_on_floor() and player.floor_slope_raycast and player.floor_slope_raycast.is_colliding():
		body_rotation = get_slope_angle()


func apply_ground_dive_physics(delta: float) -> void:
	apply_ground_friction(delta)
	
	if abs(player.velocity.x) < crouch_speed_threshold and not dive_resetting:
		if not Input.is_action_pressed("dive"):
			begin_dive_reset()


func apply_ground_friction(delta: float) -> void:
	var friction_multiplier: float = 1.0
	
	if just_landed:
		friction_multiplier = dive_landing_friction_mult
		just_landed = false
	
	var velocity_sign: float = sign(player.velocity.x)
	var speed: float = abs(player.velocity.x)
	var constant_friction: float = dive_friction_constant * friction_multiplier * delta * 60.0
	speed = max(0.0, speed - constant_friction)
	var factor_friction: float = speed * dive_friction_factor * friction_multiplier
	speed = max(0.0, speed - factor_friction)
	player.velocity.x = speed * velocity_sign


func apply_air_dive_physics(delta: float) -> void:
	if abs(player.move_dir) > 0:
		apply_dive_air_control(delta)
	
	player.velocity.x *= (1.0 - dive_air_resistance)


func apply_dive_air_control(delta: float) -> void:
	var accel: float = player.walk_acceleration
	var max_speed: float = player.run_max_speed
	var dive_accel: float = accel * dive_air_control_mult
	var vx: float = player.velocity.x
	var dir: float = player.move_dir
	
	if abs(vx) < max_speed or sign(vx) != sign(dir):
		vx = move_toward(vx, max_speed * dir, dive_accel * delta * 60.0)
	else:
		vx = move_toward(vx, max_speed * sign(vx), dive_accel * delta * 3.0)
	
	player.velocity.x = vx



func update_dive_rotation(delta: float) -> void:
	if dive_resetting:
		return
	
	var target_angle: float = 0.0
	var lerp_speed: float = 0.0
	
	if player.is_on_floor():
		if player.floor_slope_raycast and player.floor_slope_raycast.is_colliding():
			target_angle = get_slope_angle()
		else:
			target_angle = deg_to_rad(dive_flat_angle)
		
		landing_timer += delta
		lerp_speed = dive_angle_lerp_ground if landing_timer < dive_landing_smooth_time else dive_angle_lerp_ground_fast
	else:
		target_angle = get_velocity_angle()
		landing_timer = 0.0
		lerp_speed = dive_angle_lerp_air
	
	body_rotation = lerp_angle(body_rotation, target_angle, lerp_speed)
	player.sprite.rotation_degrees = rad_to_deg(body_rotation)


func get_slope_angle() -> float:
	if not player.floor_slope_raycast or not player.floor_slope_raycast.is_colliding():
		return deg_to_rad(dive_flat_angle)
	
	var normal: Vector2 = player.floor_slope_raycast.get_collision_normal()
	return normal.angle() + PI / 2


func get_velocity_angle() -> float:
	var vel_angle: float = atan2(player.velocity.y, player.velocity.x)
	var facing: int = -1 if player.sprite.flip_h else 1
	return vel_angle + PI / 2 * (1 - facing)


func begin_dive_reset() -> void:
	dive_resetting = true
	dive_reset_timer = 0.0


func update_dive_reset(delta: float) -> void:
	dive_reset_timer += delta
	var progress: float = dive_reset_timer / dive_reset_time
	
	if progress >= 1.0:
		dive_resetting = false
		player.sprite.rotation_degrees = 0.0
		return
	
	var facing: int = -1 if player.sprite.flip_h else 1
	body_rotation = -progress * (PI / 2.0) * facing
	
	if progress >= 0.5:
		body_rotation += (PI / 2.0) * facing
	
	player.sprite.rotation_degrees = rad_to_deg(body_rotation)
	player.velocity.x = move_toward(player.velocity.x, 0.0, 5.0)


func try_convert_to_ground_pound() -> bool:
	if gp_conversion_timer <= 0.0:
		return false
	
	if player.is_on_floor():
		return false
	
	var speed: float = player.velocity.length()
	var angle_rad: float = deg_to_rad(gp_dive_angle_deg)
	
	if player.velocity.x > 0:
		angle_rad = angle_rad
	else:
		angle_rad = PI - angle_rad
	
	player.velocity = Vector2(cos(angle_rad) * speed, sin(angle_rad) * speed)
	return true


func can_rollout() -> bool:
	return player.is_on_floor() and abs(player.velocity.x) >= crouch_speed_threshold and not dive_resetting


func detect_landing() -> void:
	var is_grounded: bool = player.is_on_floor()
	
	if is_grounded and not was_grounded_last_frame:
		just_landed = true
		landing_timer = 0.0
	else:
		just_landed = false
	
	was_grounded_last_frame = is_grounded
