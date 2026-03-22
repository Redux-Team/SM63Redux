@abstract class_name LDPolygonBooleanTool
extends LDTool


const MIN_POINT_DISTANCE: float = 8.0
const PREVIEW_BORDER_WIDTH: float = 1.0


var _points: PackedVector2Array
var _cursor_pos: Vector2
var _is_valid: bool = false
var _targets: Array[LDObjectPolygon] = []
var _overlay: LDSelectionOverlay
var _draw_node: LDPolygonBooleanDrawNode
var _preview_instances: Array[LDObjectPolygon] = []


func get_cursor_shape() -> Control.CursorShape:
	return Control.CURSOR_CROSS


func _on_ready() -> void:
	get_tool_handler().add_tool(self)
	viewport.viewport_moved.connect(_on_viewport_moved)


func _on_enable() -> void:
	super()
	set_cursor_shape(Control.CURSOR_CROSS)
	_overlay = viewport.get_selection_overlay()
	_overlay.draw.connect(_on_bake_overlay_draw)
	_snapshot_targets()
	_draw_node = LDPolygonBooleanDrawNode.new()
	_setup_draw_node(_draw_node)
	_overlay.add_child(_draw_node)
	_points = PackedVector2Array()
	_is_valid = false
	_spawn_preview_instances()


func _on_disable() -> void:
	for target: LDObjectPolygon in _targets:
		if is_instance_valid(target):
			target.set_selection_state(LDObject.SelectionState.HIDDEN)
			target.modulate.a = 1.0
	for poly: LDObjectPolygon in _preview_instances:
		if is_instance_valid(poly):
			poly.queue_free()
	_preview_instances.clear()
	_targets.clear()
	_points = PackedVector2Array()
	_is_valid = false
	if is_instance_valid(_draw_node):
		_draw_node.queue_free()
		_draw_node = null
	if is_instance_valid(_overlay) and _overlay.draw.is_connected(_on_bake_overlay_draw):
		_overlay.draw.disconnect(_on_bake_overlay_draw)
	super()


func _on_bake_overlay_draw() -> void:
	pass


func _on_viewport_moved(_pos: Vector2, _zoom: Vector2) -> void:
	if is_active() and is_instance_valid(_draw_node):
		_draw_node.queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_active():
		return
	if not event is InputEventKey or not event.is_pressed() or event.echo:
		return
	
	match event.keycode:
		KEY_ENTER:
			var commit_points: PackedVector2Array = _get_commit_points()
			if commit_points.size() >= 3 and _check_valid(commit_points) and _check_contact(commit_points):
				_points = commit_points
				_do_commit()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			get_tool_handler().select_tool("select")
			get_viewport().set_input_as_handled()
		KEY_BACKSPACE:
			if not _points.is_empty():
				_points.resize(_points.size() - 1)
				_update_draw_node()
			get_viewport().set_input_as_handled()


func _on_viewport_input(event: InputEvent) -> void:
	if not is_active():
		return
	if get_viewport().is_input_handled():
		return
	if Singleton.current_input_device == Singleton.InputType.TOUCHSCREEN:
		return
	
	if event is InputEventMouseMotion:
		_cursor_pos = _get_snapped_mouse_pos()
		_update_draw_node()
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not viewport.is_panning():
				var pos: Vector2 = _get_snapped_mouse_pos()
				var test: PackedVector2Array = _points.duplicate()
				test.append(pos)
				if _check_valid(test) and _check_min_distance(pos):
					_points.append(pos)
					_update_draw_node()
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var commit_points: PackedVector2Array = _get_commit_points()
			if commit_points.size() >= 3 and _check_valid(commit_points) and _check_contact(commit_points):
				_points = commit_points
				_do_commit()
			else:
				get_tool_handler().select_tool("select")


func _get_commit_points() -> PackedVector2Array:
	var pts: PackedVector2Array = _points.duplicate()
	if _cursor_pos != Vector2.ZERO and (pts.is_empty() or pts[pts.size() - 1] != _cursor_pos):
		var test: PackedVector2Array = pts.duplicate()
		test.append(_cursor_pos)
		if _check_valid(test):
			pts.append(_cursor_pos)
	return pts


func _update_draw_node() -> void:
	if not is_instance_valid(_draw_node):
		return
	
	var preview: PackedVector2Array = _points.duplicate()
	if _cursor_pos != Vector2.ZERO and (preview.is_empty() or preview[preview.size() - 1] != _cursor_pos):
		preview.append(_cursor_pos)
	
	var has_enough_points: bool = preview.size() >= 3
	var has_contact: bool = has_enough_points and _check_contact(preview)
	_is_valid = has_enough_points and _check_valid(preview) and has_contact
	
	var results: Array[PackedVector2Array] = []
	if _is_valid:
		results = _compute_preview_results(preview)
	
	_draw_node.update_data(preview, _is_valid and has_enough_points, results, _targets)
	_draw_node.queue_redraw()
	_update_preview_instances(results, preview)


func _spawn_preview_instances() -> void:
	_clear_preview_instances()
	for target: LDObjectPolygon in _targets:
		if not is_instance_valid(target):
			continue
		var game_object: GameObject = GameObjectDB.get_db().find_game_object(target.source_object_id)
		if not game_object or not game_object.ld_editor_instance:
			continue
		var instance: LDObject = game_object.ld_editor_instance.instantiate() as LDObject
		if not instance is LDObjectPolygon:
			instance.queue_free()
			continue
		var poly: LDObjectPolygon = instance as LDObjectPolygon
		poly.init_properties(game_object)
		viewport.add_object(poly)
		poly.apply_points(target._polygon.polygon.duplicate())
		poly.position = target.position
		poly.place()
		poly.modulate.a = 0.0
		_preview_instances.append(poly)


func _update_preview_instances(results: Array[PackedVector2Array], preview: PackedVector2Array) -> void:
	for poly: LDObjectPolygon in _preview_instances:
		if is_instance_valid(poly):
			poly.modulate.a = 0.0
	for target: LDObjectPolygon in _targets:
		if is_instance_valid(target):
			target.modulate.a = 1.0
	
	if results.is_empty():
		return
	
	var poly_idx: int = 0
	for i: int in _targets.size():
		var target: LDObjectPolygon = _targets[i]
		if not is_instance_valid(target):
			continue
		var target_world: PackedVector2Array = _polygon_to_world(target)
		var intersection: Array = Geometry2D.intersect_polygons(target_world, preview)
		var fully_inside: bool = preview.size() >= 3 and _is_cut_fully_inside(target_world, preview)
		if intersection.is_empty() and not fully_inside:
			continue
		
		target.modulate.a = 0.0
		
		var pieces_for_target: Array[PackedVector2Array] = _get_results_for_target(results, 0, target_world)
		
		for j: int in pieces_for_target.size():
			while poly_idx >= _preview_instances.size():
				var game_object: GameObject = GameObjectDB.get_db().find_game_object(target.source_object_id)
				if not game_object or not game_object.ld_editor_instance:
					break
				var inst: LDObject = game_object.ld_editor_instance.instantiate() as LDObject
				if not inst is LDObjectPolygon:
					inst.queue_free()
					break
				var new_poly: LDObjectPolygon = inst as LDObjectPolygon
				new_poly.init_properties(game_object)
				viewport.add_object(new_poly)
				new_poly.position = target.position
				new_poly.place()
				new_poly.modulate.a = 0.0
				_preview_instances.append(new_poly)
			
			if poly_idx >= _preview_instances.size():
				break
			if not is_instance_valid(_preview_instances[poly_idx]):
				poly_idx += 1
				continue
			
			var piece_pts: PackedVector2Array = _world_to_local(target, pieces_for_target[j])
			var preview_holes: Array[PackedVector2Array] = _compute_preview_holes_for_piece(target, preview, pieces_for_target[j])
			_preview_instances[poly_idx].position = target.position
			_preview_instances[poly_idx].apply_points_and_holes(piece_pts, preview_holes)
			_preview_instances[poly_idx].modulate.a = 1.0
			poly_idx += 1


func _compute_preview_holes(_target: LDObjectPolygon, _preview: PackedVector2Array, _piece_index: int) -> Array[PackedVector2Array]:
	return []


func _compute_preview_holes_for_piece(target: LDObjectPolygon, preview: PackedVector2Array, piece_world: PackedVector2Array) -> Array[PackedVector2Array]:
	return _compute_preview_holes(target, preview, 0)


func _clear_preview_instances() -> void:
	for poly: LDObjectPolygon in _preview_instances:
		if is_instance_valid(poly):
			poly.queue_free()
	_preview_instances.clear()
	for target: LDObjectPolygon in _targets:
		if is_instance_valid(target):
			target.set_selection_state(LDObject.SelectionState.HIDDEN)
			target.modulate.a = 1.0


func _is_cut_fully_inside(target: PackedVector2Array, cut: PackedVector2Array) -> bool:
	for p: Vector2 in cut:
		if not Geometry2D.is_point_in_polygon(p, target):
			return false
	return true


func _get_results_for_target(_results: Array[PackedVector2Array], _start_idx: int, _target_world: PackedVector2Array) -> Array[PackedVector2Array]:
	return []


func _snapshot_targets() -> void:
	_targets.clear()
	var selected: Array[LDObject] = viewport.get_selected_objects()
	var candidates: Array[LDObject] = selected if not selected.is_empty() else viewport.get_all_objects()
	for obj: LDObject in candidates:
		var poly: LDObjectPolygon = obj as LDObjectPolygon
		if poly and not poly.is_preview and poly._polygon and not poly._polygon.polygon.is_empty():
			_targets.append(poly)


func _check_contact(points: PackedVector2Array) -> bool:
	for target: LDObjectPolygon in _targets:
		if not is_instance_valid(target):
			continue
		var target_world: PackedVector2Array = _polygon_to_world(target)
		var intersection: Array = Geometry2D.intersect_polygons(points, target_world)
		if not intersection.is_empty():
			for hole: PackedVector2Array in target.get_holes():
				var hole_world: PackedVector2Array = _local_to_world(target, hole)
				var fully_inside_hole: bool = true
				for p: Vector2 in points:
					if not Geometry2D.is_point_in_polygon(p, hole_world):
						fully_inside_hole = false
						break
				if fully_inside_hole:
					return false
			return true
		if Geometry2D.is_point_in_polygon(points[0], target_world):
			return true
		if not target_world.is_empty() and Geometry2D.is_point_in_polygon(target_world[0], points):
			return true
	return false


func _check_valid(points: PackedVector2Array) -> bool:
	var count: int = points.size()
	if count < 2:
		return true
	for i: int in count:
		var a1: Vector2 = points[i]
		var a2: Vector2 = points[(i + 1) % count]
		for j: int in range(i + 2, count):
			if j == count - 1 and i == 0:
				continue
			var b1: Vector2 = points[j]
			var b2: Vector2 = points[(j + 1) % count]
			if Geometry2D.segment_intersects_segment(a1, a2, b1, b2) != null:
				return false
	return true


func _check_min_distance(pos: Vector2) -> bool:
	for existing: Vector2 in _points:
		if existing.distance_to(pos) < MIN_POINT_DISTANCE:
			return false
	return true


func _polygon_to_world(poly: LDObjectPolygon) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var xform: Transform2D = poly.get_global_transform()
	for p: Vector2 in poly.get_outer_points():
		result.append(xform * p)
	return result


func _holes_to_world(poly: LDObjectPolygon) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var xform: Transform2D = poly.get_global_transform()
	for hole: PackedVector2Array in poly.get_holes():
		var world_hole: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in hole:
			world_hole.append(xform * p)
		result.append(world_hole)
	return result


func _world_to_local(poly: LDObjectPolygon, points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var xform: Transform2D = poly.get_global_transform().affine_inverse()
	for p: Vector2 in points:
		result.append(xform * p)
	return result


func _setup_draw_node(_node: LDPolygonBooleanDrawNode) -> void:
	pass


@abstract func _compute_preview_results(points: PackedVector2Array) -> Array[PackedVector2Array]
@abstract func _commit() -> void


func _do_commit() -> void:
	_commit()
	for target: LDObjectPolygon in _targets:
		if is_instance_valid(target):
			LDCurveUtil.invalidate_curve_meta(target)


func _get_snapped_mouse_pos() -> Vector2:
	return viewport.get_root().get_local_mouse_position().snapped(Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE))


func _local_to_world(poly: LDObjectPolygon, points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var xform: Transform2D = poly.get_global_transform()
	for p: Vector2 in points:
		result.append(xform * p)
	return result
