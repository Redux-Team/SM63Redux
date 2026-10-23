class_name LDMoveTool
extends LDTool

var _objects: Array[GameObject] = []
var _before: Array[Transform2D] = []
var _start: Vector2
var _dragging: bool = false
var _tiles: Array[bool] = []


static func _is_tile(object: GameObject) -> bool:
	return object.shape is PolygonShape and (object.shape as PolygonShape).is_tiled()


func _unhandled_input(event: InputEvent) -> void:
	var direction: Vector2 = Vector2.ZERO
	if editor.is_shortcut(event, &"ld_nudge_left"):
		direction = Vector2.LEFT
	elif editor.is_shortcut(event, &"ld_nudge_right"):
		direction = Vector2.RIGHT
	elif editor.is_shortcut(event, &"ld_nudge_up"):
		direction = Vector2.UP
	elif editor.is_shortcut(event, &"ld_nudge_down"):
		direction = Vector2.DOWN
	else:
		return
	
	nudge(direction * editor.viewport_handler.snap_size)
	get_viewport().set_input_as_handled()


func _deactivate() -> void:
	if _dragging:
		_end_drag()


func _cancel() -> void:
	if not _dragging:
		return
	
	_dragging = false
	for i: int in _objects.size():
		_objects[i].transform = _before[i]


func _tool_input(event: InputEvent, world_position: Vector2) -> bool:
	if _dragging:
		return handle_drag(event, world_position)
	
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if (
			mouse_button == null
			or mouse_button.button_index != MOUSE_BUTTON_LEFT
			or not mouse_button.pressed
	):
		return false
	
	var selection: LDSelection = editor.object_handler.selection
	var hit: GameObject = editor.viewport_handler.pick(world_position)
	if hit and not selection.has(hit):
		selection.set_objects([hit])
	
	begin_drag(world_position)
	return _dragging


func is_dragging() -> bool:
	return _dragging


func begin_drag(world_position: Vector2) -> void:
	_objects = _get_movable()
	if _objects.is_empty():
		return
	
	_before = LDObjectHandler.get_transforms(_objects)
	_tiles.assign(_objects.map(_is_tile))
	_start = world_position
	_dragging = true
	editor.viewport_handler.set_cursor(Control.CURSOR_MOVE)


func handle_drag(event: InputEvent, world_position: Vector2) -> bool:
	if event is InputEventMouseMotion:
		_drag_to(world_position)
	
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button and mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
		_end_drag()
	
	return true


func nudge(offset: Vector2) -> void:
	var objects: Array[GameObject] = _get_movable()
	if objects.is_empty():
		return
	
	var before: Array[Transform2D] = LDObjectHandler.get_transforms(objects)
	for object: GameObject in objects:
		object.position += offset.sign() * TileGrid.CELL_SIZE if _is_tile(object) else offset
	
	editor.object_handler.transform_objects(
			objects,
			before,
			LDObjectHandler.get_transforms(objects),
			"Nudge Objects",
			true,
	)


func _drag_to(world_position: Vector2) -> void:
	var delta: Vector2 = world_position - _start
	for i: int in _objects.size():
		var object: GameObject = _objects[i]
		var parent_inverse: Transform2D = \
				(object.get_parent() as Node2D).get_global_transform().affine_inverse()
		var local_delta: Vector2 = parent_inverse.basis_xform(delta)
		if _tiles[i]:
			object.position = \
					_before[i].origin + local_delta.snapped(Vector2.ONE * TileGrid.CELL_SIZE)
		else:
			object.position = editor.viewport_handler.snap(_before[i].origin + local_delta)


func _end_drag() -> void:
	_dragging = false
	editor.viewport_handler.reset_cursor()
	editor.object_handler.transform_objects(
			_objects,
			_before,
			LDObjectHandler.get_transforms(_objects),
			"Move Objects",
	)


func _get_movable() -> Array[GameObject]:
	return editor.object_handler.selection.get_objects().filter(
			func(object: GameObject) -> bool:
				return object.has_flag(GameObject.Flag.MOVABLE)
	)
