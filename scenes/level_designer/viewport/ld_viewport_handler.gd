class_name LDViewportHandler
extends LDHandler

const AXIS_THRESHOLD: float = 0.92

@export var input_surface: Control
@export var camera_control: LDCameraControl
@export var overlay: LDOverlay
@export var touch_input: LDTouchInput
@export var snap_size: float = 4.0


func _setup() -> void:
	input_surface.gui_input.connect(_on_gui_input)
	editor.tool_handler.tool_changed.connect(_on_tool_changed.unbind(1))


func get_world_mouse() -> Vector2:
	return editor.world.get_global_mouse_position()


func get_layer_mouse(layer: LevelLayer) -> Vector2:
	return to_layer(layer, get_world_mouse())


func to_layer(layer: LevelLayer, world_position: Vector2) -> Vector2:
	return layer.get_objects_root().get_global_transform().affine_inverse() * world_position


func to_screen(world_position: Vector2) -> Vector2:
	return editor.world.get_canvas_transform() * world_position


func snap(local_position: Vector2) -> Vector2:
	if Input.is_action_pressed(&"ld_snap_bypass"):
		return local_position
	
	return local_position.snapped(Vector2.ONE * snap_size)


func pick(world_position: Vector2) -> GameObject:
	var objects: Array[GameObject] = editor.level_handler.get_selectable_objects()
	objects.reverse()
	for object: GameObject in objects:
		if object.has_flag(GameObject.Flag.SELECTABLE) and object.contains_point(world_position):
			return object
	
	return null


func objects_in_rect(world_rect: Rect2) -> Array[GameObject]:
	var found: Array[GameObject] = []
	for object: GameObject in editor.level_handler.get_selectable_objects():
		if object.has_flag(GameObject.Flag.SELECTABLE) and _overlaps(object, world_rect):
			found.append(object)
	
	return found


func _overlaps(object: GameObject, world_rect: Rect2) -> bool:
	if not world_rect.intersects(object.get_global_bounds()):
		return false
	if object.shape == null:
		return true
	
	var box: PackedVector2Array = PackedVector2Array([world_rect.position, Vector2(world_rect.end.x, world_rect.position.y), world_rect.end, Vector2(world_rect.position.x, world_rect.end.y)])
	var to_world: Transform2D = object.get_global_transform()
	for outline: PackedVector2Array in object.get_outlines():
		if not Geometry2D.intersect_polygons(box, to_world * outline).is_empty():
			return true
	
	return false


func store_view(area: LevelArea) -> void:
	camera_control.store_view(area)


func restore_view(area: LevelArea) -> void:
	camera_control.restore_view(area)


func _on_gui_input(event: InputEvent) -> void:
	if touch_input.handle_input(event) or camera_control.handle_input(event) or editor.tool_handler.handle_input(event, get_world_mouse()):
		input_surface.accept_event()


func set_cursor(shape: Control.CursorShape) -> void:
	input_surface.mouse_default_cursor_shape = shape


func reset_cursor() -> void:
	set_cursor(editor.tool_handler.active_tool.cursor)


static func resize_cursor(screen_direction: Vector2) -> Control.CursorShape:
	var direction: Vector2 = screen_direction.normalized()
	if absf(direction.x) > AXIS_THRESHOLD:
		return Control.CURSOR_HSIZE
	if absf(direction.y) > AXIS_THRESHOLD:
		return Control.CURSOR_VSIZE
	return Control.CURSOR_FDIAGSIZE if direction.x * direction.y > 0.0 else Control.CURSOR_BDIAGSIZE


func _on_tool_changed() -> void:
	reset_cursor()
