@abstract class_name LDPolygonBooleanTool
extends LDTool

const LASSO_MIN_DIST_SQ: float = 1600.0


var _points: PackedVector2Array = PackedVector2Array()
var _targets: Array[LDObjectPolygon] = []
var _cursor_pos: Vector2 = Vector2.ZERO
var _draw_node: LDPolygonBooleanDrawNode
var _preview_saved: Dictionary = {}
var _last_best: PackedVector2Array = PackedVector2Array()
var _is_dragging: bool = false
var _lasso_started: bool = false
var _mouse_held: bool = false
var _last_drag_pos: Vector2 = Vector2.ZERO


func _on_ready() -> void:
	get_tool_handler().add_tool(self)


func get_cursor_shape() -> Control.CursorShape:
	return Control.CursorShape.CURSOR_CROSS


func _on_enable() -> void:
	super._on_enable()
	_points = PackedVector2Array()
	_targets = []
	_preview_saved.clear()
	_last_best = PackedVector2Array()
	_draw_node = LDPolygonBooleanDrawNode.new()
	viewport.get_selection_overlay().add_child(_draw_node)
	_setup_draw_node(_draw_node)
	_cursor_pos = _get_snapped_world_pos()


func _on_disable() -> void:
	super._on_disable()
	_restore_targets()
	_points = PackedVector2Array()
	_targets = []
	_last_best = PackedVector2Array()
	if is_instance_valid(_draw_node):
		_draw_node.queue_free()
	_draw_node = null
	_is_dragging = false
	_last_drag_pos = Vector2.ZERO


func _setup_draw_node(_node: LDPolygonBooleanDrawNode) -> void:
	pass


func _input(event: InputEvent) -> void:
	if not is_active():
		return
	if not event is InputEventKey or not (event as InputEventKey).pressed or (event as InputEventKey).echo:
		return
	match (event as InputEventKey).keycode:
		KEY_ENTER:
			var commit_points: PackedVector2Array = _best_valid_points()
			if commit_points.size() >= 3:
				_targets = _find_targets_for(commit_points)
				if not _targets.is_empty():
					_restore_targets()
					_points = commit_points
					_commit()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			_restore_targets()
			_points = PackedVector2Array()
			_targets = []
			_last_best = PackedVector2Array()
			_update_draw_node()
			get_viewport().set_input_as_handled()
			_is_dragging = false
			_last_drag_pos = Vector2.ZERO
		KEY_BACKSPACE:
			if not _points.is_empty():
				_restore_targets()
				_last_best = PackedVector2Array()
				_points.resize(_points.size() - 1)
				_update_draw_node()
			get_viewport().set_input_as_handled()
			_is_dragging = false
			_last_drag_pos = Vector2.ZERO


func _on_viewport_input(event: InputEvent) -> void:
	if not is_active():
		return
	if event is InputEventMouseMotion:
		_cursor_pos = _get_snapped_world_pos()
		if _is_dragging and _mouse_held and Input.is_key_pressed(KEY_ALT):
			var snapped: Vector2 = _cursor_pos
			if _last_drag_pos == Vector2.ZERO or snapped.distance_squared_to(_last_drag_pos) >= LASSO_MIN_DIST_SQ:
				_points.append(snapped)
				_last_drag_pos = snapped
		_update_draw_node()
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_cursor_pos = _get_snapped_world_pos()
				_points.append(_cursor_pos)
				_last_drag_pos = _cursor_pos
				_mouse_held = true
				if Input.is_key_pressed(KEY_ALT):
					_is_dragging = true
					if _points.size() == 1:
						_lasso_started = true
				_update_draw_node()
			else:
				_mouse_held = false
				if _lasso_started:
					_is_dragging = false
					_last_drag_pos = Vector2.ZERO
					_lasso_started = false
					var commit_points: PackedVector2Array = _best_valid_points()
					if commit_points.size() >= 3:
						_targets = _find_targets_for(commit_points)
						if not _targets.is_empty():
							_restore_targets()
							_points = commit_points
							_commit()
							return
					_update_draw_node()
				else:
					_is_dragging = false
					_last_drag_pos = Vector2.ZERO
					_update_draw_node()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_is_dragging = false
			_mouse_held = false
			_last_drag_pos = Vector2.ZERO
			_lasso_started = false
			var commit_points: PackedVector2Array = _best_valid_points()
			if commit_points.size() >= 3:
				_targets = _find_targets_for(commit_points)
				if not _targets.is_empty():
					_restore_targets()
					_points = commit_points
					_commit()
				else:
					_restore_targets()
					_points = PackedVector2Array()
					_targets = []
					_last_best = PackedVector2Array()
			else:
				_restore_targets()
				_points = PackedVector2Array()
				_targets = []
				_last_best = PackedVector2Array()
			_update_draw_node()


func _best_valid_points() -> PackedVector2Array:
	var candidate: PackedVector2Array = _points.duplicate()
	if _cursor_pos != Vector2.ZERO and (candidate.is_empty() or candidate[candidate.size() - 1] != _cursor_pos):
		candidate.append(_cursor_pos)
	if candidate.size() >= 3 and not _find_targets_for(candidate).is_empty():
		return candidate
	var i: int = candidate.size() - 1
	while i >= 3:
		var trimmed: PackedVector2Array = candidate.slice(0, i)
		if not _find_targets_for(trimmed).is_empty():
			return trimmed
		i -= 1
	return PackedVector2Array()


func _find_targets_for(pts: PackedVector2Array) -> Array[LDObjectPolygon]:
	if pts.size() < 3:
		return []
	var result: Array[LDObjectPolygon] = []
	for obj: LDObject in viewport.get_all_objects():
		if not obj is LDObjectPolygon:
			continue
		var poly: LDObjectPolygon = obj as LDObjectPolygon
		if _preview_saved.has(poly):
			var saved: Dictionary = _preview_saved[poly] as Dictionary
			var saved_world: PackedVector2Array = PackedVector2Array()
			var xform: Transform2D = viewport.get_root().get_global_transform().affine_inverse() * poly.get_global_transform()
			for seg: LDSegment in (saved["outer"] as LDPolygon).segments:
				saved_world.append(xform * seg.point)
			if not Geometry2D.intersect_polygons(saved_world, pts).is_empty():
				result.append(poly)
		else:
			if not Geometry2D.intersect_polygons(_polygon_to_world(poly), pts).is_empty():
				result.append(poly)
	return result


func _update_draw_node() -> void:
	if not is_instance_valid(_draw_node):
		return
	var preview: PackedVector2Array = _points.duplicate()
	if _cursor_pos != Vector2.ZERO and (preview.is_empty() or preview[preview.size() - 1] != _cursor_pos):
		preview.append(_cursor_pos)
	var best: PackedVector2Array = _best_valid_points()
	var is_valid: bool = best.size() >= 3
	_draw_node.is_valid = is_valid
	var screen_preview: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in preview:
		screen_preview.append(_world_to_screen(p))
	_draw_node.points = screen_preview
	if not is_valid:
		if not _last_best.is_empty():
			_restore_targets()
			_last_best = PackedVector2Array()
		_draw_node.preview_polygons = []
		_draw_node.queue_redraw()
		return
	if best == _last_best:
		return
	_last_best = best
	_targets = _find_targets_for(best)
	_restore_targets()
	_apply_preview_to_targets(best)


func _apply_preview_to_targets(best: PackedVector2Array) -> void:
	var extra_screen_polys: Array[PackedVector2Array] = []
	for target: LDObjectPolygon in _targets:
		if not is_instance_valid(target):
			continue
		if not _preview_saved.has(target):
			_preview_saved[target] = {
				"outer": target.outer.duplicate(),
				"holes": _duplicate_holes(target.holes),
			}
		var saved: Dictionary = _preview_saved[target] as Dictionary
		var old_outer: LDPolygon = saved["outer"] as LDPolygon
		var old_holes: Array[LDPolygon] = saved["holes"] as Array[LDPolygon]
		var primary_world: PackedVector2Array = _compute_primary_piece(target, best)
		if primary_world.size() < 3:
			continue
		var new_outer: LDPolygon = old_outer.boolean_result(_world_to_local(target, primary_world))
		var new_holes: Array[LDPolygon] = _compute_preview_holes(target, best, old_holes)
		target.apply_segments(new_outer, new_holes)
		var extra_pieces: Array[PackedVector2Array] = _compute_extra_pieces(target, best)
		for piece: PackedVector2Array in extra_pieces:
			if piece.size() < 3:
				continue
			var screen_piece: PackedVector2Array = PackedVector2Array()
			for p: Vector2 in piece:
				screen_piece.append(_world_to_screen(p))
			extra_screen_polys.append(screen_piece)
	_draw_node.preview_polygons = extra_screen_polys
	_draw_node.queue_redraw()


func _compute_primary_piece(_target: LDObjectPolygon, _best: PackedVector2Array) -> PackedVector2Array:
	return PackedVector2Array()


func _compute_preview_holes(_target: LDObjectPolygon, _best: PackedVector2Array, _old_holes: Array[LDPolygon]) -> Array[LDPolygon]:
	return []


func _compute_extra_pieces(_target: LDObjectPolygon, _best: PackedVector2Array) -> Array[PackedVector2Array]:
	return []


func _restore_targets() -> void:
	for target: Variant in _preview_saved.keys():
		var poly: LDObjectPolygon = target as LDObjectPolygon
		if not is_instance_valid(poly):
			continue
		var saved: Dictionary = _preview_saved[target] as Dictionary
		poly.apply_segments(
			saved["outer"] as LDPolygon,
			saved["holes"] as Array[LDPolygon]
		)
	_preview_saved.clear()


func _commit() -> void:
	pass


func _polygon_to_world(poly: LDObjectPolygon) -> PackedVector2Array:
	var xform: Transform2D = viewport.get_root().get_global_transform().affine_inverse() * poly.get_global_transform()
	var result: PackedVector2Array = PackedVector2Array()
	for seg: LDSegment in poly.outer.segments:
		result.append(xform * seg.point)
	return result


func _holes_to_world(poly: LDObjectPolygon) -> Array[PackedVector2Array]:
	var xform: Transform2D = viewport.get_root().get_global_transform().affine_inverse() * poly.get_global_transform()
	var result: Array[PackedVector2Array] = []
	for h: LDPolygon in poly.holes:
		var hw: PackedVector2Array = PackedVector2Array()
		for seg: LDSegment in h.segments:
			hw.append(xform * seg.point)
		result.append(hw)
	return result


func _world_to_local(poly: LDObjectPolygon, world_pts: PackedVector2Array) -> PackedVector2Array:
	var xform: Transform2D = viewport.get_root().get_global_transform().affine_inverse() * poly.get_global_transform()
	var inv: Transform2D = xform.affine_inverse()
	var result: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in world_pts:
		result.append(inv * p)
	return result


func _local_to_world(poly: LDObjectPolygon, local_pts: PackedVector2Array) -> PackedVector2Array:
	var xform: Transform2D = viewport.get_root().get_global_transform().affine_inverse() * poly.get_global_transform()
	var result: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in local_pts:
		result.append(xform * p)
	return result


func _match_hole(old_holes: Array[LDPolygon], new_flat: PackedVector2Array) -> LDPolygon:
	var best: LDPolygon = null
	var best_ratio: float = 0.4
	for old_h: LDPolygon in old_holes:
		var old_flat: PackedVector2Array = old_h.to_flat()
		var matched: int = 0
		for op: Vector2 in old_flat:
			for np: Vector2 in new_flat:
				if op.distance_squared_to(np) < LDPolygon.SNAP_SQ:
					matched += 1
					break
		var ratio: float = float(matched) / float(old_flat.size())
		if ratio > best_ratio:
			best_ratio = ratio
			best = old_h
	return best


func _duplicate_holes(src: Array[LDPolygon]) -> Array[LDPolygon]:
	var result: Array[LDPolygon] = []
	for h: LDPolygon in src:
		result.append(h.duplicate())
	return result


func _world_to_screen(world_pos: Vector2) -> Vector2:
	var full_xform: Transform2D = get_viewport().get_canvas_transform() * viewport.get_root().get_global_transform()
	return full_xform * world_pos


func _get_snapped_world_pos() -> Vector2:
	return viewport.get_root().get_local_mouse_position().snapped(Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE))
