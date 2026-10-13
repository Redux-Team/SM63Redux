class_name LDCameraControl
extends LDComponent

@export var camera: Camera2D
@export var min_zoom: float = 0.05
@export var max_zoom: float = 4.0
@export var zoom_step: float = 1.15
@export var pan_speed: float = 600.0

var _panning: bool = false


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
		_panning = event.is_pressed()
		return true
	
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button and mouse_button.button_index == MOUSE_BUTTON_LEFT and Input.is_action_pressed(&"ld_pan_hold"):
		_panning = mouse_button.pressed
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


func pan(screen_delta: Vector2) -> void:
	camera.position += screen_delta / camera.zoom


func zoom_at(factor: float, screen_position: Vector2) -> void:
	var half_size: Vector2 = camera.get_viewport_rect().size / 2.0
	var anchor: Vector2 = camera.position + (screen_position - half_size) / camera.zoom
	camera.zoom = Vector2.ONE * clampf(camera.zoom.x * factor, min_zoom, max_zoom)
	camera.position = anchor - (screen_position - half_size) / camera.zoom


func reset() -> void:
	camera.position = Vector2.ZERO
	camera.zoom = Vector2.ONE
	for object: GameObject in editor.level_handler.active_area.get_all_objects():
		if object.unique:
			camera.position = object.global_position
			return


func store_view(area: LevelArea) -> void:
	area.camera_position = camera.position
	area.camera_zoom = camera.zoom.x


func restore_view(area: LevelArea) -> void:
	camera.position = area.camera_position
	camera.zoom = Vector2.ONE * clampf(area.camera_zoom, min_zoom, max_zoom)


func _mouse_position(event: InputEvent) -> Vector2:
	var mouse: InputEventMouse = event as InputEventMouse
	return mouse.position if mouse else camera.get_viewport_rect().size / 2.0
