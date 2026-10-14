class_name LevelCamera
extends Camera2D

const MAX_SLIDES: int = 4
const PHYSICS_PRIORITY: int = 100
const BLOCK_EPSILON: float = 0.01
const LIMIT_REACH: float = 4096.0
const LIMIT_DIRECTIONS: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]

@export var target: CharacterBody2D
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var follow_halflife: float = 0.14
@export_group("Look Ahead")
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var look_ahead_time: float = 0.45
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var look_ahead_max: float = 96.0
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var look_ahead_halflife: float = 0.35
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var turbo_look_ahead_time: float = 0.6
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var turbo_look_ahead_max: float = 200.0
@export_group("Vertical Bias")
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var ground_bias: float = -20.0
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var fall_bias: float = 28.0
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var fall_threshold: float = 250.0
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var fall_ramp: float = 400.0
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var bias_halflife: float = 0.7
@export_group("Zoom")
@export var zoom_min: float = 1.0
@export var zoom_max: float = 3.0
@export var zoom_step: float = 0.5
@export var zoom_smoothing_speed: float = 10.0
@export_group("Stoppers")
@export_flags_2d_physics var stopper_mask: int = 4096
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var stopper_inset: float = 1.0

var _previous: Vector2
var _current: Vector2
var _lead: Vector2
var _focus: Vector2
var _desired: Vector2
var _resolved_previous: Vector2
var _resolved_current: Vector2
var _blocked: Vector2
var _limit_min: Vector2 = -Vector2.INF
var _limit_max: Vector2 = Vector2.INF
var _stopper: CharacterBody2D
var _view_box: RectangleShape2D
var _target_zoom: float = 0.0
var _shake_strength: float = 0.0
var _shake_duration: float = 0.0
var _shake_elapsed: float = 0.0


func _ready() -> void:
	process_physics_priority = PHYSICS_PRIORITY
	_target_zoom = zoom.x
	_view_box = RectangleShape2D.new()
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = _view_box
	_stopper = CharacterBody2D.new()
	_stopper.top_level = true
	_stopper.collision_layer = 0
	_stopper.collision_mask = stopper_mask
	_stopper.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_stopper.add_child(collision)
	add_child(_stopper)


func follow(body: CharacterBody2D) -> void:
	target = body
	_previous = body.global_position
	_current = body.global_position
	_focus = body.global_position
	_lead = Vector2.ZERO
	_desired = _focus
	_resolved_previous = _focus
	_resolved_current = _focus
	_blocked = Vector2.ZERO
	_limit_min = -Vector2.INF
	_limit_max = Vector2.INF
	_stopper.global_position = _focus
	global_position = _focus
	offset = Vector2.ZERO
	reset_smoothing()


func shake(strength: float, duration: float) -> void:
	if not Settings.gameplay.screen_shake.current_value:
		return
	
	_shake_strength = strength
	_shake_duration = duration
	_shake_elapsed = 0.0


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(target):
		return
	
	_previous = _current
	_current = target.global_position
	_resolved_previous = _resolved_current
	_resolved_current = _resolve(_desired)
	var correction: Vector2 = _resolved_current - _desired
	_blocked = Vector2(float(absf(correction.x) > BLOCK_EPSILON), float(absf(correction.y) > BLOCK_EPSILON))
	_measure_limits()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"camera_zoom_in"):
		_target_zoom = clampf(_target_zoom + zoom_step, zoom_min, zoom_max)
	elif event.is_action_pressed(&"camera_zoom_out"):
		_target_zoom = clampf(_target_zoom - zoom_step, zoom_min, zoom_max)
	else:
		return
	
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	zoom = Vector2.ONE * lerpf(zoom.x, _target_zoom, 1.0 - exp(-zoom_smoothing_speed * delta))
	if not is_instance_valid(target):
		return
	
	var followed: Vector2 = _previous.lerp(_current, Engine.get_physics_interpolation_fraction())
	_focus = Vector2(Motion.damp(_focus.x, followed.x, follow_halflife, delta), Motion.damp(_focus.y, followed.y, follow_halflife, delta))
	var turbo: bool = target is Player and (target as Player).fludd.is_turbo_active()
	var reach: float = turbo_look_ahead_max if turbo else look_ahead_max
	var lead: float = clampf(target.velocity.x * (turbo_look_ahead_time if turbo else look_ahead_time), -reach, reach)
	_lead.x = Motion.damp(_lead.x, lead, look_ahead_halflife, delta)
	_lead.y = Motion.damp(_lead.y, _vertical_bias(), bias_halflife, delta)
	_desired = _focus + _lead
	var resolved: Vector2 = _resolved_previous.lerp(_resolved_current, Engine.get_physics_interpolation_fraction())
	var free: Vector2 = Vector2(resolved.x if _blocked.x > 0.0 else _desired.x, resolved.y if _blocked.y > 0.0 else _desired.y)
	global_position = free.clamp(_limit_min, _limit_max)
	offset = _shake_offset(delta)


func _resolve(desired: Vector2) -> Vector2:
	_view_box.size = (get_viewport_rect().size / zoom - Vector2.ONE * stopper_inset * 2.0).maxf(1.0)
	var motion: Vector2 = desired - _stopper.global_position
	for i: int in MAX_SLIDES:
		var hit: KinematicCollision2D = _stopper.move_and_collide(motion)
		if hit == null:
			break
		motion = hit.get_remainder().slide(hit.get_normal())
		if motion.is_zero_approx():
			break
	
	return _stopper.global_position


func _measure_limits() -> void:
	var origin: Vector2 = _stopper.global_position
	var reach: Dictionary[Vector2, float] = {}
	var hit: KinematicCollision2D = KinematicCollision2D.new()
	for direction: Vector2 in LIMIT_DIRECTIONS:
		var blocked: bool = _stopper.test_move(_stopper.global_transform, direction * LIMIT_REACH, hit)
		reach.set(direction, hit.get_travel().length() if blocked else INF)
	
	_limit_min = Vector2(origin.x - reach.get(Vector2.LEFT), origin.y - reach.get(Vector2.UP))
	_limit_max = Vector2(origin.x + reach.get(Vector2.RIGHT), origin.y + reach.get(Vector2.DOWN))


func _vertical_bias() -> float:
	if target.is_on_floor():
		return ground_bias
	
	if target.velocity.y > fall_threshold:
		return lerpf(_lead.y, fall_bias, smoothstep(0.0, 1.0, (target.velocity.y - fall_threshold) / fall_ramp))
	
	return _lead.y


func _shake_offset(delta: float) -> Vector2:
	if _shake_elapsed >= _shake_duration:
		return Vector2.ZERO
	
	_shake_elapsed += delta
	var progress: float = minf(_shake_elapsed / _shake_duration, 1.0)
	var decay: float = 1.0 - progress * progress
	var angle: float = _shake_elapsed * 60.0
	return Vector2(cos(angle * 1.3), sin(angle)) * _shake_strength * decay
