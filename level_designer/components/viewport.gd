class_name LDViewport
extends Control

static var scroll_speed: float = 5.0
static var _inst: LDViewport

@export var anchor: Control

var zoom_amount: float

var zoom_tween: Tween


static func get_instance() -> LDViewport:
	return _inst


func add_object(obj: LDObject) -> LDObject:
	pass
	return obj


func _ready() -> void:
	_inst = self
	zoom_tween = create_tween()


func _process(_delta: float) -> void:
	_panning_handler()


func _input(event: InputEvent) -> void:
	_zoom_handler(event)
	
	if event is InputEventPanGesture:
		_panning_handler(event)


func _panning_handler(event: InputEventPanGesture = null) -> void:
	if event:
		anchor.position += -event.delta * scroll_speed
		return
	
	var x_axis: float = Input.get_axis(&"editor_pan_right", &"editor_pan_left")
	var y_axis: float = Input.get_axis(&"editor_pan_down", &"editor_pan_up")
	
	anchor.position += Vector2(x_axis, y_axis) * scroll_speed


func _zoom_handler(event: InputEvent) -> void:
	if event.is_action_pressed(&"editor_zoom_in"):
		smooth_zoom(0.5)
	elif event.is_action_pressed(&"editor_zoom_out"):
		smooth_zoom(-0.5)


func smooth_zoom(amount: float, location: Vector2 = Vector2(0.5, 0.5)) -> void:
	var old_scale: float = zoom_amount
	zoom_amount += amount
	zoom_amount = max(0.1, zoom_amount) # prevent negative or zero scale
	
	# Calculate the world position under the zoom point before zooming
	var viewport_size: Vector2 = get_viewport_rect().size
	var zoom_point: Vector2 = anchor.position + (location * viewport_size - anchor.position) / old_scale
	
	zoom_tween.kill()
	zoom_tween = create_tween()
	zoom_tween.tween_property(anchor, "scale", Vector2(zoom_amount, zoom_amount), 0.3)
	
	var new_position: Vector2 = zoom_point - (location * viewport_size - anchor.position) / zoom_amount
	zoom_tween.tween_property(anchor, "position", new_position, 0.3)
