extends State

const SLIDE_ANGLE_LERP_SPEED: float = 0.5
const SLIDE_FLAT_ANGLE: float = 90.0

var body_rotation: float = 0.0
var entered_from_dive: bool = false


func _on_enter(from: StringName) -> void:
	player.lock_flipping = true
	player._internal_friction_multiplier = 0.5
	entered_from_dive = from == "Dive"
	
	if entered_from_dive:
		body_rotation = deg_to_rad(player.sprite.rotation_degrees)
	else:
		if player.floor_slope_raycast and player.floor_slope_raycast.is_colliding():
			body_rotation = get_slope_angle()
		else:
			body_rotation = deg_to_rad(SLIDE_FLAT_ANGLE)


func _on_exit(_to: StringName) -> void:
	player.lock_flipping = false
	player._internal_friction_multiplier = 1.0
	body_rotation = 0.0
	player.sprite.rotation_degrees = 0.0


func _physics_process(_delta: float) -> void:
	if player.is_on_floor():
		player.apply_friction()


func _process(delta: float) -> void:
	update_slide_rotation(delta)


func update_slide_rotation(_delta: float) -> void:
	var target_angle: float
	
	if player.floor_slope_raycast and player.floor_slope_raycast.is_colliding():
		target_angle = get_slope_angle()
	else:
		target_angle = deg_to_rad(SLIDE_FLAT_ANGLE)
	
	body_rotation = lerp_angle(body_rotation, target_angle, SLIDE_ANGLE_LERP_SPEED)
	player.sprite.rotation_degrees = rad_to_deg(body_rotation)


func get_slope_angle() -> float:
	if not player.floor_slope_raycast or not player.floor_slope_raycast.is_colliding():
		return deg_to_rad(SLIDE_FLAT_ANGLE)
	
	var normal: Vector2 = player.floor_slope_raycast.get_collision_normal()
	return normal.angle() + PI / 2
