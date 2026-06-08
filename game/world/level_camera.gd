class_name LevelCamera
extends CharacterBody2D


signal anchor_changed(new_anchor: Node2D)


static var _inst: LevelCamera


@export_group("Zoom")
@export var default_zoom: float = 1.5
@export var zoom_min: float = 0.5
@export var zoom_max: float = 3.0
@export var zoom_step: float = 0.5
@export var zoom_smoothing_speed: float = 10.0
@export var allow_input_zoom: bool = true

@export_group("Position")
@export var position_smoothing_speed: float = 10.0

@export_group("Look Ahead")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "look_ahead_") var look_ahead_enabled: bool = false
@export var look_ahead_distance: float = 100.0
@export var look_ahead_smoothing_speed: float = 5.0
@export_subgroup("Horizontal")
@export var look_ahead_x_min_speed: float = 10.0
@export var look_ahead_x_max_speed: float = 300.0
@export var look_ahead_x_curve: Curve
@export_subgroup("Vertical")
@export var look_ahead_y_min_speed: float = 200.0
@export var look_ahead_y_max_speed: float = 600.0
@export var look_ahead_y_curve: Curve

@export_group("Rotation")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "rotate_") var rotate_with_object: bool = false
@export var rotate_smoothing_speed: float = 5.0

@export_group("References")
@export var _camera: Camera2D
@export var _bounds_shape: RectangleShape2D
@export var _remote_transform: RemoteTransform2D


var _anchor: Node2D = null
var _anchor_offset: Vector2 = Vector2.ZERO
var _target_zoom: float = 1.0
var _look_ahead_offset: Vector2 = Vector2.ZERO
var _prev_anchor_position: Vector2 = Vector2.ZERO
var _frozen: bool = false


func _init() -> void:
	_inst = self


func _ready() -> void:
	_target_zoom = default_zoom
	_camera.zoom = Vector2.ONE * default_zoom
	_remote_transform.remote_path = _camera.get_path()


func _process(delta: float) -> void:
	_update_zoom(delta)
	if rotate_with_object and is_instance_valid(_anchor):
		_camera.rotation = _anchor.rotation


func _physics_process(delta: float) -> void:
	_update_look_ahead(delta)
	_apply_anchor_position()


static func get_instance() -> LevelCamera:
	return _inst


static func get_camera() -> Camera2D:
	return _inst._camera


func anchor_to_object(object: Node2D, anchor_offset: Vector2 = Vector2.ZERO) -> void:
	if is_instance_valid(_anchor) and _anchor.tree_exiting.is_connected(_on_anchor_exiting_tree):
		_anchor.tree_exiting.disconnect(_on_anchor_exiting_tree)
	_anchor = object
	_anchor_offset = anchor_offset
	if is_instance_valid(_anchor):
		_prev_anchor_position = _anchor.global_position
		_anchor.tree_exiting.connect(_on_anchor_exiting_tree, CONNECT_ONE_SHOT)
	anchor_changed.emit(object)


func set_anchor_offset(anchor_offset: Vector2) -> void:
	_anchor_offset = anchor_offset


func shake(strength: float, duration: float) -> void:
	var base_offset: Vector2 = _anchor_offset
	var elapsed: float = 0.0
	while elapsed < duration:
		var delta: float = get_process_delta_time()
		elapsed += delta
		var t: float = elapsed / duration
		var decay: float = 1.0 - t * t
		var angle: float = elapsed * 60.0
		_anchor_offset = base_offset + Vector2(
			cos(angle * 1.3) * strength * decay,
			sin(angle) * strength * decay
		)
		await get_tree().process_frame
	_anchor_offset = base_offset


func freeze() -> void:
	_frozen = true


func unfreeze() -> void:
	_frozen = false


func _update_zoom(delta: float) -> void:
	var new_zoom: float = lerpf(_camera.zoom.x, _target_zoom, zoom_smoothing_speed * delta)
	_camera.zoom = Vector2.ONE * new_zoom
	_bounds_shape.size = _camera.get_viewport_rect().size / _camera.zoom


func _update_look_ahead(delta: float) -> void:
	if not look_ahead_enabled or not is_instance_valid(_anchor):
		_look_ahead_offset = _look_ahead_offset.lerp(Vector2.ZERO, look_ahead_smoothing_speed * delta)
		return
	
	var vel: Vector2
	var body: CharacterBody2D = _anchor as CharacterBody2D
	if is_instance_valid(body):
		vel = body.velocity
	else:
		vel = (_anchor.global_position - _prev_anchor_position) / delta
	
	_prev_anchor_position = _anchor.global_position
	
	var target_offset: Vector2 = Vector2(
		_evaluate_look_ahead_axis(vel.x, look_ahead_x_min_speed, look_ahead_x_max_speed, look_ahead_x_curve),
		_evaluate_look_ahead_axis(vel.y, look_ahead_y_min_speed, look_ahead_y_max_speed, look_ahead_y_curve)
	) * look_ahead_distance
	
	_look_ahead_offset = _look_ahead_offset.lerp(target_offset, look_ahead_smoothing_speed * delta)


func _evaluate_look_ahead_axis(speed: float, min_speed: float, max_speed: float, curve: Curve) -> float:
	var abs_speed: float = absf(speed)
	if abs_speed < min_speed or not is_instance_valid(curve):
		return 0.0
	var t: float = clampf((abs_speed - min_speed) / (max_speed - min_speed), 0.0, 1.0)
	return signf(speed) * curve.sample_baked(t)


func _apply_anchor_position() -> void:
	if _frozen:
		velocity = Vector2.ZERO
		return
	if not is_instance_valid(_anchor):
		velocity = Vector2.ZERO
		return
	var target: Vector2 = _anchor.global_position + _anchor_offset + _look_ahead_offset
	velocity = (target - global_position) * position_smoothing_speed
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if not allow_input_zoom:
		return
	if event.is_action_pressed(&"camera_zoom_in"):
		_target_zoom = clampf(_target_zoom + zoom_step, zoom_min, zoom_max)
	elif event.is_action_pressed(&"camera_zoom_out"):
		_target_zoom = clampf(_target_zoom - zoom_step, zoom_min, zoom_max)


func _on_anchor_exiting_tree() -> void:
	_anchor = null
