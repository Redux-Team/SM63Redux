class_name LDCameraControl
extends LDComponent

const GLIDE_DURATION: float = 0.45
const BUILD_DURATION: float = 0.9
const ARRIVE_DURATION: float = 0.55
const DEPART_DURATION: float = 0.6
const DEPART_ZOOM: float = 0.35
const OVERVIEW_MARGIN: float = 0.85

@export var camera: Camera2D
@export var min_zoom: float = 0.05
@export var max_zoom: float = 4.0
@export var zoom_step: float = 1.15
@export var pan_speed: float = 600.0

var _panning: bool = false
var _glide: Tween


func _process(delta: float) -> void:
	if not editor.accepts_shortcuts() or Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META):
		return
	
	var direction: Vector2 = Input.get_vector(&"ld_pan_left", &"ld_pan_right", &"ld_pan_up", &"ld_pan_down")
	camera.position += direction * pan_speed * delta / camera.zoom.x
	var zoom_axis: float = Input.get_axis(&"ld_zoom_out_axis", &"ld_zoom_in_axis")
	if not is_zero_approx(zoom_axis):
		zoom_at(pow(zoom_step, zoom_axis * delta * 8.0), camera.get_viewport_rect().size / 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return
	
	if editor.is_shortcut(event, &"ld_camera_reset"):
		reset()
	elif editor.is_shortcut(event, &"ld_zoom_in"):
		zoom_at(zoom_step, camera.get_viewport_rect().size / 2.0)
	elif editor.is_shortcut(event, &"ld_zoom_out"):
		zoom_at(1.0 / zoom_step, camera.get_viewport_rect().size / 2.0)
	else:
		return
	
	get_viewport().set_input_as_handled()


func handle_input(event: InputEvent) -> bool:
	if event.is_action(&"ld_pan"):
		_set_panning(event.is_pressed())
		return true
	
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button and mouse_button.button_index == MOUSE_BUTTON_LEFT and Input.is_action_pressed(&"ld_pan_hold"):
		_set_panning(mouse_button.pressed)
		return true
	
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion and _panning:
		pan(-motion.relative)
		return true
	
	if event.is_action_pressed(&"ld_zoom_in"):
		zoom_at(zoom_step, _mouse_position(event))
		return true
	
	if event.is_action_pressed(&"ld_zoom_out"):
		zoom_at(1.0 / zoom_step, _mouse_position(event))
		return true
	
	var magnify: InputEventMagnifyGesture = event as InputEventMagnifyGesture
	if magnify:
		zoom_at(magnify.factor, magnify.position)
		return true
	
	var gesture: InputEventPanGesture = event as InputEventPanGesture
	if gesture:
		pan(gesture.delta * 8.0)
		return true
	
	return false


func _set_panning(panning: bool) -> void:
	if panning == _panning:
		return
	
	_panning = panning
	if panning:
		editor.viewport_handler.set_cursor(Control.CURSOR_DRAG)
	else:
		editor.viewport_handler.reset_cursor()


func pan(screen_delta: Vector2) -> void:
	_stop_glide()
	camera.position += screen_delta / camera.zoom


func zoom_at(factor: float, screen_position: Vector2) -> void:
	_stop_glide()
	var half_size: Vector2 = camera.get_viewport_rect().size / 2.0
	var anchor: Vector2 = camera.position + (screen_position - half_size) / camera.zoom
	camera.zoom = Vector2.ONE * clampf(camera.zoom.x * factor, min_zoom, max_zoom)
	camera.position = anchor - (screen_position - half_size) / camera.zoom


func reset() -> void:
	glide_to(_home(editor.level_handler.active_area), 1.0)


func depart() -> void:
	glide_to(camera.position, camera.zoom.x * DEPART_ZOOM, DEPART_DURATION)


func reveal(area: LevelArea) -> void:
	var objects: Array[GameObject] = area.get_all_objects().filter(func(object: GameObject) -> bool: return object.visible)
	if objects.is_empty() or not Settings.ui.animations.current_value:
		glide_to(_home(area), 1.0, 0.0)
		return
	
	var bounds: Rect2 = objects.front().get_global_bounds()
	for object: GameObject in objects:
		bounds = bounds.merge(object.get_global_bounds())
		object.visible = false
	
	var view: Vector2 = camera.get_viewport_rect().size
	var fit: float = minf(view.x / maxf(bounds.size.x, 1.0), view.y / maxf(bounds.size.y, 1.0)) * OVERVIEW_MARGIN
	glide_to(bounds.get_center(), minf(fit, 1.0), 0.0)
	objects.sort_custom(func(a: GameObject, b: GameObject) -> bool: return a.global_position.x < b.global_position.x)
	var started: int = Time.get_ticks_msec()
	var shown: int = 0
	while shown < objects.size():
		await get_tree().process_frame
		var progress: float = clampf((Time.get_ticks_msec() - started) / 1000.0 / BUILD_DURATION, 0.0, 1.0)
		var target: int = ceili(objects.size() * ease(progress, 0.6))
		while shown < target:
			var object: GameObject = objects.get(shown)
			if is_instance_valid(object):
				object.visible = true
			shown += 1
	
	glide_to(_home(area), 1.0, ARRIVE_DURATION)


func glide_to(target_position: Vector2, target_zoom: float, duration: float = GLIDE_DURATION) -> void:
	if _glide and _glide.is_valid():
		_glide.kill()
	
	target_zoom = clampf(target_zoom, min_zoom, max_zoom)
	if not Settings.ui.animations.current_value or duration <= 0.0:
		camera.position = target_position
		camera.zoom = Vector2.ONE * target_zoom
		return
	
	_glide = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_glide.tween_property(camera, ^"position", target_position, duration)
	_glide.tween_property(camera, ^"zoom", Vector2.ONE * target_zoom, duration)


func _home(area: LevelArea) -> Vector2:
	for object: GameObject in area.get_all_objects():
		if object.unique:
			return object.global_position
	
	return Vector2.ZERO


func store_view(area: LevelArea) -> void:
	area.camera_position = camera.position
	area.camera_zoom = camera.zoom.x


func _stop_glide() -> void:
	if _glide and _glide.is_valid():
		_glide.kill()


func restore_view(area: LevelArea) -> void:
	_stop_glide()
	camera.position = area.camera_position
	camera.zoom = Vector2.ONE * clampf(area.camera_zoom, min_zoom, max_zoom)


func _mouse_position(event: InputEvent) -> Vector2:
	var mouse: InputEventMouse = event as InputEventMouse
	return mouse.position if mouse else camera.get_viewport_rect().size / 2.0
