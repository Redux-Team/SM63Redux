extends LDTool


@export var shortcut_handler: LDSelectionShortcutHandler

var _is_box_selecting: bool = false
var _is_shift_selecting: bool = false
var _box_select_origin: Vector2
var _box_select_rect: Rect2
var _overlay: LDSelectionOverlay
var _move_tool: LDToolMove


func get_tool_name() -> String:
	return "Select"


func _on_ready() -> void:
	get_tool_handler().add_tool(self)
	_overlay = viewport.get_selection_overlay() as LDSelectionOverlay
	LD.get_object_handler().selected_object_changed.connect(_on_selected_object_changed)
	viewport.touch_tap.connect(_on_touch_tap)
	viewport.touch_swipe_began.connect(_on_touch_swipe_began)
	viewport.touch_swipe_moved.connect(_on_touch_swipe_moved)
	viewport.touch_swipe_ended.connect(_on_touch_swipe_ended)


func _on_viewport_input(event: InputEvent) -> void:
	if not is_active():
		return
	if Singleton.get_input_handler().is_using_touch():
		return
	
	if shortcut_handler:
		shortcut_handler.handle_input(event)
	
	if event is InputEventKey and event.is_pressed() and not event.echo:
		if event.keycode == KEY_BACKSPACE or event.keycode == KEY_DELETE:
			_delete_selected()
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var mouse_pos: Vector2 = _get_mouse_pos()
			var move: LDToolMove = _get_move_tool()
			if move and move.try_begin_drag(mouse_pos, viewport.get_selected_objects()):
				_move_tool = move
				get_tool_handler().select_tool("move")
				return
			
			var clicked: LDObject = _get_object_at(mouse_pos)
			if clicked:
				var game_object: GameObject = GameDB.get_db().find_game_object(clicked.source_object_id)
				if game_object.ld_select_tool_override:
					viewport.set_selected_objects([clicked])
					get_tool_handler().select_tool(game_object.ld_select_tool_override)
					return
			
			_is_box_selecting = true
			_is_shift_selecting = event.shift_pressed
			_box_select_origin = mouse_pos
			_box_select_rect = Rect2(_box_select_origin, Vector2.ZERO)
		else:
			_is_box_selecting = false
			_commit_box_select()
			_overlay.hide_box()
	
	if event is InputEventMouseMotion and _is_box_selecting:
		_box_select_rect = Rect2(_box_select_origin, _get_mouse_pos() - _box_select_origin).abs()
		_overlay.show_box(_box_select_rect)
		_update_hover_states()


func _on_enable() -> void:
	if _move_tool and not _move_tool.is_dragging():
		_move_tool = null


func _on_disable() -> void:
	_overlay.hide_box()
	_is_box_selecting = false


func _on_selected_object_changed(_obj: GameObject) -> void:
	viewport.clear_selection()
	_overlay.hide_box()
	_is_box_selecting = false


func _update_hover_states() -> void:
	for obj: LDObject in viewport.get_all_objects_on_layer():
		var game_obj: GameObject = GameDB.get_db().find_game_object(obj.source_object_id)
		if not game_obj.ld_flags & (1 << GameObject.LD_SELECTABLE):
			continue
		if obj.is_preview:
			continue
		if obj in viewport.get_selected_objects():
			obj.set_selection_state(LDObject.SelectionState.SELECTED)
			continue
		if _object_intersects_box(obj):
			obj.set_selection_state(LDObject.SelectionState.HOVERED)
		else:
			obj.set_selection_state(LDObject.SelectionState.HIDDEN)


func _commit_box_select() -> void:
	if _box_select_rect.size.length() < 4.0:
		var clicked: LDObject = _get_object_at(_box_select_origin)
		if _is_shift_selecting:
			var combined: Array[LDObject] = viewport.get_selected_objects().duplicate()
			if clicked:
				if clicked not in combined:
					combined.append(clicked)
				else:
					combined.erase(clicked)
			viewport.set_selected_objects(combined)
		else:
			var single: Array[LDObject] = []
			if clicked:
				single.append(clicked)
			viewport.set_selected_objects(single)
		return
	
	var found: Array[LDObject] = []
	for obj: LDObject in viewport.get_all_objects_on_layer():
		if obj.is_preview:
			continue
		if _object_intersects_box(obj):
			found.append(obj)
	
	if _is_shift_selecting:
		var combined: Array[LDObject] = viewport.get_selected_objects().duplicate()
		for obj: LDObject in found:
			if obj not in combined:
				combined.append(obj)
		viewport.set_selected_objects(combined)
	else:
		viewport.set_selected_objects(found)


func _delete_selected() -> void:
	var to_delete: Array[LDObject] = viewport.get_selected_objects().duplicate()
	viewport.clear_selection()
	for obj: LDObject in to_delete:
		obj.queue_free()


func _get_shape_screen_points(shape: CollisionShape2D) -> PackedVector2Array:
	var rect: Rect2 = (shape.shape as RectangleShape2D).get_rect()
	var corners: Array[Vector2] = [
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + rect.size,
		rect.position + Vector2(0.0, rect.size.y),
	]
	var full_transform: Transform2D = viewport.get_viewport().get_canvas_transform() * shape.get_global_transform()
	var points: PackedVector2Array = PackedVector2Array()
	for corner: Vector2 in corners:
		points.append(full_transform * corner)
	return points


func _point_near_polygon_edge(point: Vector2, screen_points: PackedVector2Array, threshold: float) -> bool:
	var count: int = screen_points.size()
	for i: int in count:
		var a: Vector2 = screen_points[i]
		var b: Vector2 = screen_points[(i + 1) % count]
		if Geometry2D.get_closest_point_to_segment(point, a, b).distance_to(point) <= threshold:
			return true
	return false


func _polygon_edge_intersects_box(screen_points: PackedVector2Array, box: Rect2) -> bool:
	var count: int = screen_points.size()
	var box_corners: Array[Vector2] = [
		box.position,
		box.position + Vector2(box.size.x, 0.0),
		box.position + Vector2(0.0, box.size.y),
		box.position + box.size,
	]
	var box_edges: Array[Array] = [
		[box_corners[0], box_corners[1]],
		[box_corners[1], box_corners[3]],
		[box_corners[3], box_corners[2]],
		[box_corners[2], box_corners[0]],
	]
	for i: int in count:
		var a: Vector2 = screen_points[i]
		var b: Vector2 = screen_points[(i + 1) % count]
		if box.has_point(a):
			return true
		for edge: Array in box_edges:
			if Geometry2D.segment_intersects_segment(a, b, edge[0], edge[1]) != null:
				return true
	return false


func _object_intersects_box(obj: LDObject) -> bool:
	var poly_obj: LDObjectPolygon = obj as LDObjectPolygon
	if poly_obj and poly_obj.editor_polygon:
		var full_transform: Transform2D = viewport.get_viewport().get_canvas_transform() * obj.get_global_transform()
		var screen_points: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in poly_obj.editor_polygon.polygon:
			screen_points.append(full_transform * point)
		
		if poly_obj.polygon_data and poly_obj.polygon_data.edge_selection:
			return _polygon_edge_intersects_box(screen_points, _box_select_rect)
		
		for p: Vector2 in screen_points:
			if _box_select_rect.has_point(p):
				return true
		var box_corners: Array[Vector2] = [
			_box_select_rect.position,
			_box_select_rect.position + Vector2(_box_select_rect.size.x, 0.0),
			_box_select_rect.position + Vector2(0.0, _box_select_rect.size.y),
			_box_select_rect.position + _box_select_rect.size,
		]
		for corner: Vector2 in box_corners:
			if Geometry2D.is_point_in_polygon(corner, screen_points):
				return true
		var count: int = screen_points.size()
		var box_edges: Array[Array] = [
			[_box_select_rect.position, _box_select_rect.position + Vector2(_box_select_rect.size.x, 0.0)],
			[_box_select_rect.position + Vector2(_box_select_rect.size.x, 0.0), _box_select_rect.position + _box_select_rect.size],
			[_box_select_rect.position + _box_select_rect.size, _box_select_rect.position + Vector2(0.0, _box_select_rect.size.y)],
			[_box_select_rect.position + Vector2(0.0, _box_select_rect.size.y), _box_select_rect.position],
		]
		for i: int in count:
			var a1: Vector2 = screen_points[i]
			var a2: Vector2 = screen_points[(i + 1) % count]
			for edge: Array in box_edges:
				if Geometry2D.segment_intersects_segment(a1, a2, edge[0], edge[1]) != null:
					return true
		return false
	
	var areas: Array[Area2D] = obj.get_all_editor_shape_areas()
	if areas.is_empty():
		var half: Vector2 = obj.get_stamp_size() * 0.5
		var screen_rect: Rect2 = viewport.world_rect_to_screen(obj.global_position - half, obj.get_stamp_size())
		return _box_select_rect.intersects(screen_rect)
	
	var box_corners: Array[Vector2] = [
		_box_select_rect.position,
		_box_select_rect.position + Vector2(_box_select_rect.size.x, 0.0),
		_box_select_rect.position + Vector2(0.0, _box_select_rect.size.y),
		_box_select_rect.position + _box_select_rect.size,
	]
	var box_edges: Array[Array] = [
		[_box_select_rect.position, _box_select_rect.position + Vector2(_box_select_rect.size.x, 0.0)],
		[_box_select_rect.position + Vector2(_box_select_rect.size.x, 0.0), _box_select_rect.position + _box_select_rect.size],
		[_box_select_rect.position + _box_select_rect.size, _box_select_rect.position + Vector2(0.0, _box_select_rect.size.y)],
		[_box_select_rect.position + Vector2(0.0, _box_select_rect.size.y), _box_select_rect.position],
	]
	
	for area: Area2D in areas:
		for child: Node in area.get_children():
			var shape: CollisionShape2D = child as CollisionShape2D
			if not shape or not shape.shape is RectangleShape2D:
				continue
			var points: PackedVector2Array = _get_shape_screen_points(shape)
			for p: Vector2 in points:
				if _box_select_rect.has_point(p):
					return true
			for corner: Vector2 in box_corners:
				if Geometry2D.is_point_in_polygon(corner, points):
					return true
			var count: int = points.size()
			for i: int in count:
				var a1: Vector2 = points[i]
				var a2: Vector2 = points[(i + 1) % count]
				for edge: Array in box_edges:
					if Geometry2D.segment_intersects_segment(a1, a2, edge[0], edge[1]) != null:
						return true
	
	return false


func _get_object_at(mouse_pos: Vector2) -> LDObject:
	var all: Array[LDObject] = viewport.get_all_objects_on_layer()
	for i: int in range(all.size() - 1, -1, -1):
		var obj: LDObject = all[i]
		if obj.is_preview:
			continue
		var poly_obj: LDObjectPolygon = obj as LDObjectPolygon
		if poly_obj and poly_obj._polygon:
			var full_transform: Transform2D = viewport.get_viewport().get_canvas_transform() * obj.get_global_transform()
			var screen_points: PackedVector2Array = PackedVector2Array()
			for point: Vector2 in poly_obj._polygon.polygon:
				screen_points.append(full_transform * point)
			if poly_obj.polygon_data and poly_obj.polygon_data.edge_selection:
				if _point_near_polygon_edge(mouse_pos, screen_points, 6.0):
					return obj
			elif Geometry2D.is_point_in_polygon(mouse_pos, screen_points):
				return obj
			continue
		var areas: Array[Area2D] = obj.get_all_editor_shape_areas()
		if areas.is_empty():
			var half: Vector2 = obj.get_stamp_size() * 0.5
			var screen_rect: Rect2 = viewport.world_rect_to_screen(obj.global_position - half, obj.get_stamp_size())
			if screen_rect.has_point(mouse_pos):
				return obj
			continue
		for area: Area2D in areas:
			for child: Node in area.get_children():
				var shape: CollisionShape2D = child as CollisionShape2D
				if not shape or not shape.shape is RectangleShape2D:
					continue
				var points: PackedVector2Array = _get_shape_screen_points(shape)
				if Geometry2D.is_point_in_polygon(mouse_pos, points):
					return obj
	
	return null


func _get_move_tool() -> LDToolMove:
	return get_tool_handler().get_tool_list().filter(func(t: LDTool) -> bool:
		return t is LDToolMove
	).front() as LDToolMove


func _get_mouse_pos() -> Vector2:
	return _overlay.get_local_mouse_position()


func _on_touch_tap(pos: Vector2) -> void:
	if not is_active():
		return
	var obj: LDObject = _get_object_at(pos)
	if obj:
		viewport.set_selected_objects([obj])
		if obj is LDObjectPath:
			get_tool_handler().select_tool("path_edit")
		elif obj is LDObjectPolygon:
			get_tool_handler().select_tool("polygon_edit")
	else:
		viewport.clear_selection()


func _on_touch_swipe_began(pos: Vector2) -> void:
	if not is_active():
		return
	_is_box_selecting = true
	_is_shift_selecting = false
	_box_select_origin = pos
	_box_select_rect = Rect2(pos, Vector2.ZERO)


func _on_touch_swipe_moved(pos: Vector2) -> void:
	if not is_active():
		return
	_box_select_rect = Rect2(_box_select_origin, pos - _box_select_origin).abs()
	_overlay.show_box(_box_select_rect)
	_update_hover_states()


func _on_touch_swipe_ended() -> void:
	if not is_active():
		return
	_is_box_selecting = false
	_commit_box_select()
	_overlay.hide_box()
