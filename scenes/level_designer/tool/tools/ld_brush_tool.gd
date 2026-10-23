class_name LDBrushTool
extends LDPlaceTool

var _stroke: Array[GameObject] = []
var _last: Vector2
var _painting: bool = false


func _deactivate() -> void:
	if _painting:
		_end_stroke()
	super()


func _cancel() -> void:
	_painting = false
	for object: GameObject in _stroke:
		object.free()
	_stroke = []


func _tool_input(event: InputEvent, _world_position: Vector2) -> bool:
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		if mouse_button.pressed and editor.tool_handler.armed:
			_painting = true
			_paint(get_snapped_mouse())
		elif not mouse_button.pressed and _painting:
			_end_stroke()
		return true
	
	if event is InputEventMouseMotion and _painting:
		var target: Vector2 = get_snapped_mouse()
		if (
				absf(target.x - _last.x) >= _get_spacing().x
				or absf(target.y - _last.y) >= _get_spacing().y
		):
			_paint(target)
		return true
	
	return false


func _paint(local_position: Vector2) -> void:
	var object: GameObject = create_object(local_position)
	editor.level_handler.active_layer.add_object(object)
	_stroke.append(object)
	_last = local_position


func _end_stroke() -> void:
	_painting = false
	for object: GameObject in _stroke:
		object.get_parent().remove_child(object)
	
	editor.object_handler.add_objects(
			_stroke,
			editor.level_handler.active_layer,
			"Brush %s" % editor.tool_handler.armed.display_name,
			false,
	)
	_stroke = []


func _get_spacing() -> Vector2:
	return (
			_preview.get_local_bounds().size
			if _preview
			else Vector2.ONE * editor.viewport_handler.snap_size
	)
