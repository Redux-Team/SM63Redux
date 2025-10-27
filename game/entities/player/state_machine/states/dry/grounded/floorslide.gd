extends State

const SLIDE_ANGLE_LERP_SPEED: float = 0.5
const SLIDE_FLAT_ANGLE: float = 90.0
const AIRBORNE_NOSEDIVE_SPEED: float = 0.15
const MAX_NOSEDIVE_ANGLE: float = -45.0
const LEDGE_BUFFER_TIME: float = 0.15

var body_rotation: float = 0.0
var entered_from_dive: bool = false
var time_since_grounded: float = 0.0
var last_slope_angle: float = 0.0


func _on_enter(from: StringName) -> void:
	player.lock_flipping = true
	player._internal_friction_multiplier = 0.4
	entered_from_dive = from == "Dive"
	time_since_grounded = 0.0
	
	if entered_from_dive:
		body_rotation = deg_to_rad(player.sprite.rotation_degrees)
		last_slope_angle = body_rotation
	else:
		if player.floor_slope_raycast and player.floor_slope_raycast.is_colliding():
			body_rotation = get_slope_angle()
			last_slope_angle = body_rotation
		else:
			body_rotation = deg_to_rad(SLIDE_FLAT_ANGLE)
			last_slope_angle = body_rotation


func _on_exit(_to: StringName) -> void:
	player.lock_flipping = false
	player._internal_friction_multiplier = 1.0
	body_rotation = 0.0
	player.sprite.rotation_degrees = 0.0


func _physics_process(_delta: float) -> void:
	if player.is_on_floor():
		player.apply_friction()
		time_since_grounded = 0.0
	else:
		time_since_grounded += _delta


func _process(_delta: float) -> void:
	update_slide_rotation()


func update_slide_rotation() -> void:
	var target_angle: float
	var is_in_ledge_buffer: bool = time_since_grounded < LEDGE_BUFFER_TIME
	
	if player.is_on_floor() and player.floor_slope_raycast and player.floor_slope_raycast.is_colliding():
		target_angle = get_slope_angle()
		last_slope_angle = target_angle
		body_rotation = lerp_angle(body_rotation, target_angle, SLIDE_ANGLE_LERP_SPEED)
	elif is_in_ledge_buffer:
		body_rotation = lerp_angle(body_rotation, last_slope_angle, SLIDE_ANGLE_LERP_SPEED)
	elif not player.is_on_floor():
		target_angle = deg_to_rad(MAX_NOSEDIVE_ANGLE)
		body_rotation = lerp_angle(body_rotation, target_angle, AIRBORNE_NOSEDIVE_SPEED)
	else:
		target_angle = deg_to_rad(SLIDE_FLAT_ANGLE)
		body_rotation = lerp_angle(body_rotation, target_angle, SLIDE_ANGLE_LERP_SPEED)
	
	player.sprite.rotation_degrees = rad_to_deg(body_rotation)


func get_slope_angle() -> float:
	if not player.floor_slope_raycast or not player.floor_slope_raycast.is_colliding():
		return deg_to_rad(SLIDE_FLAT_ANGLE)
	
	var normal: Vector2 = player.floor_slope_raycast.get_collision_normal()
	return normal.angle() + PI / 2
