@abstract class_name LDDragPlaceTool
extends LDPlaceTool

var _origin: Vector2
var _dragging: bool = false


func _process(_delta: float) -> void:
	var layer: LevelLayer = editor.level_handler.active_layer
	if _preview == null or layer == null:
		return
	
	preview_root.global_transform = layer.get_objects_root().get_global_transform()
	if _dragging:
		_resize_preview(_preview, _origin, get_snapped_mouse())
	else:
		_idle_preview(_preview, get_snapped_mouse())


func _deactivate() -> void:
	_dragging = false
	super()


func _cancel() -> void:
	_dragging = false


func _tool_input(event: InputEvent, _world_position: Vector2) -> bool:
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button == null or editor.tool_handler.armed == null:
		return false
	
	if mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed and _dragging:
		_dragging = false
		return true
	
	if mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return false
	
	if mouse_button.pressed:
		_origin = get_snapped_mouse()
		_dragging = true
	elif _dragging:
		_dragging = false
		var object: GameObject = create_object(Vector2.ZERO)
		_resize_preview(object, _origin, get_snapped_mouse())
		editor.object_handler.add_objects(
				[object],
				editor.level_handler.active_layer,
				"Place %s" % editor.tool_handler.armed.display_name,
				false,
		)
	return true


@abstract func _resize_preview(object: GameObject, origin: Vector2, current: Vector2) -> void


@abstract func _idle_preview(object: GameObject, at: Vector2) -> void
