extends State


const SLIDE_ANGLE_LERP_SPEED: float = 0.5
const AIRBORNE_NOSEDIVE_SPEED: float = 0.15
const LEDGE_BUFFER_TIME: float = 0.15

@export var slide_flat_angle: float = 90.0
@export var max_nosedive_angle: float = 45.0
@export var rotation_offset: float = -90.0

var body_rotation: float = 0.0
var entered_from_dive: bool = false
var time_since_grounded: float = 0.0
var last_slope_angle: float = 0.0


func _on_enter(from: StringName) -> void:
	player.lock_flipping = true
	player.set_friction_scale_factor(1.6)
	entered_from_dive = from == &"Dive"
	time_since_grounded = 0.0
	
	if entered_from_dive:
		body_rotation = deg_to_rad(player.sprite.rotation_degrees)
	elif player.floor_slope_raycast and player.floor_slope_raycast.is_colliding():
		body_rotation = get_slope_angle()
	else:
		body_rotation = deg_to_rad(slide_flat_angle)
	
	last_slope_angle = body_rotation


func _on_exit(_to: StringName) -> void:
	player.lock_flipping = false
	player.set_friction_scale_factor(1.0)
	body_rotation = 0.0
	player.sprite.rotation_degrees = 0.0


func _physics_process(delta: float) -> void:
	if player.is_on_floor():
		time_since_grounded = 0.0
	else:
		player.velocity.y += 1
		time_since_grounded += delta


func _process(_delta: float) -> void:
	update_slide_rotation()


func update_slide_rotation() -> void:
	var is_in_ledge_buffer: bool = time_since_grounded < LEDGE_BUFFER_TIME
	
	if player.is_on_floor() and player.floor_slope_raycast and player.floor_slope_raycast.is_colliding():
		var target_angle: float = get_slope_angle()
		last_slope_angle = target_angle
		body_rotation = lerp_angle(body_rotation, target_angle, SLIDE_ANGLE_LERP_SPEED)
	elif is_in_ledge_buffer:
		body_rotation = lerp_angle(body_rotation, last_slope_angle, SLIDE_ANGLE_LERP_SPEED)
	elif not player.is_on_floor():
		var facing: float = -1.0 if player.sprite.flip_h else 1.0
		var nosedive_angle: float = deg_to_rad(max_nosedive_angle) * facing
		body_rotation = lerp_angle(body_rotation, nosedive_angle, AIRBORNE_NOSEDIVE_SPEED)
	else:
		body_rotation = lerp_angle(body_rotation, 0.0, SLIDE_ANGLE_LERP_SPEED)
	
	player.sprite.rotation_degrees = rad_to_deg(body_rotation)


func get_slope_angle() -> float:
	if not player.floor_slope_raycast or not player.floor_slope_raycast.is_colliding():
		return deg_to_rad(slide_flat_angle)
	var normal: Vector2 = player.floor_slope_raycast.get_collision_normal()
	return normal.angle() + PI / 2.0
