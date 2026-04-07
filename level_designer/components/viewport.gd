class_name LDViewport
extends Control


static var scroll_speed: float = 3.0
static var zoom_step: float = 0.5
static var zoom_min: float = 0.1
static var zoom_max: float = 10.0
static var zoom_duration: float = 0.3
static var _inst: LDViewport

@export var anchor: Control

var mouse_panning: bool = false
var zoom_amount: float = 1.0
var zoom_tween: Tween


static func get_instance() -> LDViewport:
	return _inst


func add_object(obj: GameObject) -> GameObject:
	return obj


func _ready() -> void:
	_inst = self


func _input(event: InputEvent) -> void:
	# Zooming
	# Zoom on mouse
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				smooth_zoom(zoom_step / 5.0, get_mouse_zoom_location())
			MOUSE_BUTTON_WHEEL_DOWN:
				smooth_zoom(-zoom_step / 5.0, get_mouse_zoom_location())
	# Standard zooming
	if event.is_action_pressed(&"_editor_zoom_in"):
		smooth_zoom(zoom_step)
	if event.is_action_pressed(&"_editor_zoom_out"):
		smooth_zoom(-zoom_step)
	
	# (Mouse panning)
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE when event.is_pressed():
				mouse_panning = true
			MOUSE_BUTTON_MIDDLE when event.is_released():
				mouse_panning = false
	if event is InputEventMouseMotion and mouse_panning:
		anchor.position += event.relative
		if zoom_tween and zoom_tween.is_running():
			zoom_tween.kill()


func _process(_delta: float) -> void:
	var x_pan: float = Input.get_axis(&"_editor_pan_left", &"_editor_pan_right")
	var y_pan: float = Input.get_axis(&"_editor_pan_up", &"_editor_pan_down")
	anchor.position -= Vector2(x_pan, y_pan) * scroll_speed


func get_mouse_zoom_location() -> Vector2:
	var mouse_pos: Vector2 = get_local_mouse_position()
	var viewport_size: Vector2 = get_viewport_rect().size
	return mouse_pos / viewport_size


func smooth_zoom(amount: float, location: Vector2 = Vector2(0.5, 0.5)) -> void:
	var old_zoom: float = zoom_amount
	zoom_amount += amount
	zoom_amount = clamp(zoom_amount, zoom_min, zoom_max)
	
	var viewport_size: Vector2 = get_viewport_rect().size
	var zoom_point_viewport: Vector2 = location * viewport_size
	var zoom_point_world: Vector2 = (zoom_point_viewport - anchor.position) / old_zoom
	var new_position: Vector2 = zoom_point_viewport - zoom_point_world * zoom_amount
	
	if zoom_tween:
		zoom_tween.kill()
	zoom_tween = create_tween()
	zoom_tween.set_parallel()
	zoom_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	zoom_tween.tween_property(anchor, ^"scale", Vector2(zoom_amount, zoom_amount), zoom_duration)
	zoom_tween.tween_property(anchor, ^"position", new_position, zoom_duration)
