class_name GlideState
extends PlayerState

@export_group("Flight")
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s^2") var max_lift: float = 2000.0
@export_custom(PROPERTY_HINT_NONE, "suffix:/s") var steer_rate: float = 5.0
@export_custom(PROPERTY_HINT_NONE, "suffix:deg/s")
var max_turn_rate: float = 220.0
@export_custom(PROPERTY_HINT_NONE, "suffix:/s") var drag_rate: float = 0.032
@export_custom(PROPERTY_HINT_NONE, "suffix:/s") var climb_drag: float = 0.35
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var min_speed: float = 8.4
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var input_halflife: float = 0.05
@export_group("Entry")
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var entry_speed: float = 200.0
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var entry_halflife: float = 0.12
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var entry_time: float = 0.6
@export_range(0.0, 1.0, 0.01) var entry_rise_kept: float = 0.35
@export_group("Turn Around")
@export_range(0.0, 90.0, 0.1, "degrees") var up_window: float = 25.7
@export_range(0.0, 90.0, 0.1, "degrees") var down_window: float = 18.0
@export_range(0.0, 1.0, 0.01) var turn_speed_kept: float = 0.9
@export_group("Exit")
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var slide_speed: float = 150.0
@export_group("Visual")
@export_custom(PROPERTY_HINT_NONE, "suffix:s")
var rotation_halflife: float = 0.0
@export var up_animation: StringName = &"fly_up"
@export var down_animation: StringName = &"fly_down"

var _input: float = 0.0
var _body_rotation: float = 0.0


func _enter() -> void:
	player.lock_flipping = true
	if player.velocity.y < 0.0:
		player.velocity.y *= entry_rise_kept
	_input = 0.0
	_body_rotation = get_heading()


func _tick(delta: float) -> void:
	_input = Motion.damp(_input, -controls.glide, input_halflife, delta)
	var before: Vector2 = player.velocity
	_ease_entry(delta)
	_steer(delta)
	_turn_around()
	var drag: float = drag_rate + climb_drag * maxf(-player.velocity.normalized().y, 0.0)
	player.velocity *= exp(-drag * delta)
	if player.velocity.length() < min_speed:
		player.velocity = (
				Vector2(player.get_facing(), 0.0).rotated(get_heading() * player.get_facing())
				* min_speed
		)
	
	player.debug_forces[&"lift"] = (player.velocity - before) / delta + player.velocity * drag
	player.debug_forces[&"drag"] = -player.velocity * drag
	player.debug_forces[&"gravity"] = Vector2(0.0, player.get_gravity_strength())


func _render_tick(delta: float) -> void:
	if rotation_halflife <= 0.0:
		_body_rotation = get_heading()
	else:
		_body_rotation = Motion.damp_angle(_body_rotation, get_heading(), rotation_halflife, delta)
	sprite.local_rotation = rad_to_deg(_body_rotation)
	var animation: StringName = up_animation if controls.glide < 0.0 else down_animation
	if sprite.current_animation != animation:
		sprite.play(animation)


func _exit() -> void:
	player.debug_forces.clear()
	player.lock_flipping = false
	sprite.rotation_degrees = 0.0


func _next() -> StringName:
	if player.is_on_floor():
		return &"Floorslide" if absf(player.velocity.x) >= slide_speed else &"Idle"
	if player.is_on_wall() or player.is_on_ceiling() or not player.caps.is_running(&"Wing"):
		return &"Fall"
	return &""


func get_heading() -> float:
	return atan2(player.velocity.y, player.velocity.x * player.get_facing())


func _ease_entry(delta: float) -> void:
	var forward: float = player.velocity.x * player.get_facing()
	if time > entry_time or forward >= entry_speed:
		return
	
	player.velocity.x = \
			Motion.damp(forward, entry_speed, entry_halflife, delta) * player.get_facing()


func _steer(delta: float) -> void:
	var speed: float = player.velocity.length()
	if is_zero_approx(_input) or speed <= 0.0:
		return
	
	var target: float = -PI / 2.0 if _input > 0.0 else PI / 2.0
	var heading: float = get_heading()
	var eased: float = (target - heading) * (1.0 - exp(-steer_rate * delta))
	var limit: float = minf(max_lift / speed, deg_to_rad(max_turn_rate)) * delta
	var turn: float = clampf(eased, -limit, limit) * absf(_input)
	player.velocity = player.velocity.rotated(turn * player.get_facing())


func _turn_around() -> void:
	var heading: float = get_heading()
	var near_up: bool = heading < deg_to_rad(up_window) - PI / 2.0
	var near_down: bool = heading > PI / 2.0 - deg_to_rad(down_window)
	if (near_up or near_down) and controls.move * player.get_facing() < -0.5:
		player.velocity.x *= -turn_speed_kept
		sprite.flip_h = not sprite.flip_h
