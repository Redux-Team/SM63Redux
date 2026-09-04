@abstract class_name LDPolygonBooleanTool
extends LDTool


const MIN_POINT_DISTANCE: float = 8.0


@export var _draw_node_scene: PackedScene = preload("res://level_designer/components/tool_handler/tools/polygon/polygon_draw_node.tscn")

var _points: PackedVector2Array
var _cursor_pos: Vector2
var _is_valid: bool = false
var _targets: Array[LDObjectPolygon] = []
var _overlay: LDSelectionOverlay
var _draw_node: LDPolygonBooleanDrawNode
var _preview_instances: Dictionary[LDObjectPolygon, Array] = {}
var _preview_root: Node2D


@abstract func _compute_preview_results(points: PackedVector2Array) -> Array[PackedVector2Array]
@abstract func _commit() -> void


func get_cursor_shape() -> Control.CursorShape:
	return Control.CURSOR_CROSS


func _on_ready() -> void:
	get_tool_handler().add_tool(self)
	viewport.viewport_moved.connect(_on_viewport_moved)


func _on_enable() -> void:
	super()
	set_cursor_shape(Control.CURSOR_CROSS)
	_overlay = viewport.get_selection_overlay()
	_snapshot_targets()
	_draw_node = _draw_node_scene.instantiate() as LDPolygonBooleanDrawNode
	if _draw_node:
		_setup_draw_node(_draw_node)
		_overlay.add_child(_draw_node)
	_points = PackedVector2Array()
	_is_valid = false
	_spawn_preview_instances()


func _on_disable() -> void:
	_clear_preview_instances()
	_targets.clear()
	_points = PackedVector2Array()
	_is_valid = false
	if is_instance_valid(_draw_node):
		_draw_node.queue_free()
		_draw_node = null
	super()


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
			_try_commit()
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
	if Singleton.get_input_handler().is_using_touch():
		return
	
	if event is InputEventMouseMotion:
		_cursor_pos = viewport.get_snapped_mouse()
		_update_draw_node()
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not viewport.is_panning():
				var pos: Vector2 = viewport.get_snapped_mouse()
				var test: PackedVector2Array = _points.duplicate()
				test.append(pos)
				if _check_valid(test) and _check_min_distance(pos):
					_points.append(pos)
					_update_draw_node()
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if not _try_commit():
				get_tool_handler().select_tool("select")


## Commits the stroke the cursor is currently closing, if it is one this tool can act on.
## Returns whether anything was committed.
func _try_commit() -> bool:
	var commit_points: PackedVector2Array = _get_commit_points()
	if commit_points.size() < 3:
		return false
	if not _check_valid(commit_points) or not _check_contact(commit_points):
		return false
	_points = commit_points
	_commit()
	return true


## The stroke as drawn so far plus the point under the cursor, which is what the user sees and
## therefore what a commit has to act on.
func _preview_points() -> PackedVector2Array:
	var preview: PackedVector2Array = _points.duplicate()
	if _cursor_pos != Vector2.ZERO and (preview.is_empty() or preview.get(preview.size() - 1) != _cursor_pos):
		preview.append(_cursor_pos)
	return preview


func _get_commit_points() -> PackedVector2Array:
	var pts: PackedVector2Array = _preview_points()
	if pts.size() > _points.size() and not _check_valid(pts):
		return _points.duplicate()
	return pts


func _update_draw_node() -> void:
	var preview: PackedVector2Array = _preview_points()
	var has_enough_points: bool = preview.size() >= 3
	_is_valid = has_enough_points and _check_valid(preview) and _check_contact(preview)
	
	var results: Array[PackedVector2Array] = []
	if _is_valid:
		results = _compute_preview_results(preview)
	
	if is_instance_valid(_draw_node):
		_draw_node.update_data(preview, _is_valid, results)
		_draw_node.queue_redraw()
	_update_preview_instances(results, preview)


## An invisible stand-in for [param target] that the preview reshapes instead of the real object,
## so the level itself is never touched until the stroke is committed. It is placed like any other
## object - flagging it [member LDObject.is_preview] would repaint it as a placement ghost - and
## kept out of the level by its parent instead.
func _make_preview_clone(target: LDObjectPolygon, game_object: GameObject) -> LDObjectPolygon:
	if not game_object:
		return null
	var instance: LDObject = game_object.get_editor_instance()
	var poly: LDObjectPolygon = instance as LDObjectPolygon
	if not poly:
		instance.queue_free()
		return null
	_get_preview_root().add_child(poly)
	poly.init_properties(game_object)
	poly.polygon_data = target.polygon_data
	poly.apply_points_and_holes(target.get_outer_points(), target.get_holes())
	poly.position = target.position
	poly.place()
	poly.modulate.a = 0.0
	return poly


## The clones' own parent, under the active layer's object root so they inherit the layer's
## transform. Everything that walks the level - the save serializer, the object caches the
## selection tools read - looks at that root's direct children only, so a clone one level further
## down is placed for rendering yet invisible to all of them.
func _get_preview_root() -> Node2D:
	if not is_instance_valid(_preview_root):
		_preview_root = Node2D.new()
		LD.get_area().get_active_layer().get_objects_root().add_child(_preview_root)
	return _preview_root


func _spawn_preview_instances() -> void:
	_clear_preview_instances()
	for target: LDObjectPolygon in _targets:
		if not is_instance_valid(target):
			continue
		var clone: LDObjectPolygon = _make_preview_clone(target, GameDB.get_object(target.source_object_id))
		if clone:
			_preview_instances.set(target, [clone])


func _update_preview_instances(results: Array[PackedVector2Array], preview: PackedVector2Array) -> void:
	for target: LDObjectPolygon in _targets:
		if not is_instance_valid(target):
			continue
		for poly: LDObjectPolygon in _preview_instances.get(target, []):
			if is_instance_valid(poly):
				poly.modulate.a = 0.0
		target.modulate.a = 1.0
	
	if results.is_empty():
		return
	
	for target: LDObjectPolygon in _targets:
		if not is_instance_valid(target):
			continue
		var target_world: PackedVector2Array = _polygon_to_world(target)
		var touched: bool = not Geometry2D.intersect_polygons(target_world, preview).is_empty()
		if not touched and not (preview.size() >= 3 and _is_cut_fully_inside(target_world, preview)):
			continue
		
		target.modulate.a = 0.0
		
		var pieces: Array[PackedVector2Array] = _get_results_for_target(results, target_world)
		var pool: Array = _preview_instances.get(target, [])
		var game_object: GameObject = GameDB.get_object(target.source_object_id)
		
		while pool.size() < pieces.size():
			var clone: LDObjectPolygon = _make_preview_clone(target, game_object)
			if not clone:
				break
			pool.append(clone)
		
		_preview_instances.set(target, pool)
		
		for j: int in pieces.size():
			var poly: LDObjectPolygon = pool.get(j) if j < pool.size() else null
			if not is_instance_valid(poly):
				continue
			poly.polygon_data = target.polygon_data
			poly.position = target.position
			poly.apply_points_and_holes(
				_world_to_local(target, pieces.get(j)),
				_compute_preview_holes_for_piece(target, preview, pieces.get(j))
			)
			poly.modulate.a = 1.0


func _compute_preview_holes(_target: LDObjectPolygon, _preview: PackedVector2Array) -> Array[PackedVector2Array]:
	return []


func _compute_preview_holes_for_piece(target: LDObjectPolygon, preview: PackedVector2Array, _piece_world: PackedVector2Array) -> Array[PackedVector2Array]:
	return _compute_preview_holes(target, preview)


func _clear_preview_instances() -> void:
	_preview_instances.clear()
	if is_instance_valid(_preview_root):
		_preview_root.queue_free()
		_preview_root = null
	for target: LDObjectPolygon in _targets:
		if is_instance_valid(target):
			target.set_selection_state(LDObject.SelectionState.HIDDEN)
			target.modulate.a = 1.0


func _get_results_for_target(_results: Array[PackedVector2Array], _target_world: PackedVector2Array) -> Array[PackedVector2Array]:
	return []


func _snapshot_targets() -> void:
	_targets.clear()
	var selected: Array[LDObject] = viewport.get_selected_objects()
	var candidates: Array[LDObject] = selected if not selected.is_empty() else LD.get_area().get_all_objects_on_layer()
	for obj: LDObject in candidates:
		var poly: LDObjectPolygon = obj as LDObjectPolygon
		if poly and not poly.is_preview and not poly.get_ring().is_empty():
			_targets.append(poly)


func _check_contact(points: PackedVector2Array) -> bool:
	for target: LDObjectPolygon in _targets:
		if not is_instance_valid(target):
			continue
		var target_world: PackedVector2Array = _polygon_to_world(target)
		if not Geometry2D.intersect_polygons(points, target_world).is_empty():
			for hole_world: PackedVector2Array in _holes_to_world(target):
				if _is_cut_fully_inside(hole_world, points):
					return false
			return true
		if Geometry2D.is_point_in_polygon(points.get(0), target_world):
			return true
		if not target_world.is_empty() and Geometry2D.is_point_in_polygon(target_world.get(0), points):
			return true
	return false


func _check_valid(points: PackedVector2Array) -> bool:
	var count: int = points.size()
	if count < 2:
		return true
	for i: int in count:
		var a1: Vector2 = points.get(i)
		var a2: Vector2 = points.get((i + 1) % count)
		for j: int in range(i + 2, count):
			if j == count - 1 and i == 0:
				continue
			var b1: Vector2 = points.get(j)
			var b2: Vector2 = points.get((j + 1) % count)
			if Geometry2D.segment_intersects_segment(a1, a2, b1, b2) != null:
				return false
	return true


func _check_min_distance(pos: Vector2) -> bool:
	for existing: Vector2 in _points:
		if existing.distance_to(pos) < MIN_POINT_DISTANCE:
			return false
	return true


func _is_cut_fully_inside(target: PackedVector2Array, cut: PackedVector2Array) -> bool:
	for p: Vector2 in cut:
		if not Geometry2D.is_point_in_polygon(p, target):
			return false
	return true


## Drops everything a boolean result cannot be built from: stray fragments and rings that collapse
## once their duplicate and collinear points are gone.
func _clean_pieces(pieces: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for piece: PackedVector2Array in pieces:
		if piece.size() < 3:
			continue
		var cleaned: PackedVector2Array = TerrainPolygon.clean_polygon(piece)
		if cleaned.size() >= 3:
			result.append(cleaned)
	return result


## Grows [param cut] by every hole it reaches into, so the union can be taken out of the outer ring
## in a single clip. Indices of the holes the cut never touched are appended to [param surviving].
func _absorb_holes(holes_world: Array[PackedVector2Array], cut: PackedVector2Array, surviving: Array[int]) -> PackedVector2Array:
	var combined: PackedVector2Array = cut
	for i: int in holes_world.size():
		var hole: PackedVector2Array = holes_world.get(i)
		if Geometry2D.intersect_polygons(hole, cut).is_empty():
			surviving.append(i)
			continue
		var merged: Array[PackedVector2Array] = Geometry2D.merge_polygons(hole, combined)
		if not merged.is_empty():
			combined = TerrainPolygon.clean_polygon(merged.front())
	return combined


func _centroid(points: PackedVector2Array) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var sum: Vector2 = Vector2.ZERO
	for p: Vector2 in points:
		sum += p
	return sum / points.size()


func _offset_points(points: PackedVector2Array, delta: Vector2) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in points:
		result.append(p + delta)
	return result


## Restores a polygon to one shape in one rebuild. Every history action these tools push is some
## form of this, so they all go through here.
func _reshape(obj: LDObjectPolygon, points: PackedVector2Array, holes: Array[PackedVector2Array]) -> void:
	if not is_instance_valid(obj):
		return
	obj.modulate.a = 1.0
	obj.apply_points_and_holes(points, holes)


func _reshape_action(obj: LDObjectPolygon, points: PackedVector2Array, holes: Array[PackedVector2Array]) -> Callable:
	return func() -> void:
		_reshape(obj, points, holes)


## Drops objects a history action detached from the tree out of the selection, so nothing keeps
## pointing at a node that is no longer in the level.
func _prune_selection() -> void:
	var remaining: Array[LDObject] = []
	for obj: LDObject in viewport.get_selected_objects():
		if is_instance_valid(obj) and obj.is_inside_tree():
			remaining.append(obj)
	if remaining.size() != viewport.get_selected_objects().size():
		viewport.set_selected_objects(remaining)


## A target's own points in the space the cut is drawn in. The cut is authored where the cursor
## is - the active layer - so a target on another layer is read and written through the step
## between the two, which is the identity for the usual same-layer target.
func _target_transform(poly: LDObjectPolygon) -> Transform2D:
	return viewport.layer_to_world(poly) * poly.transform


func _polygon_to_world(poly: LDObjectPolygon) -> PackedVector2Array:
	return _local_to_world(poly, poly.get_outer_points())


func _holes_to_world(poly: LDObjectPolygon) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for hole: PackedVector2Array in poly.get_holes():
		result.append(_local_to_world(poly, hole))
	return result


func _local_to_world(poly: LDObjectPolygon, points: PackedVector2Array) -> PackedVector2Array:
	return _transform_points(_target_transform(poly), points)


func _world_to_local(poly: LDObjectPolygon, points: PackedVector2Array) -> PackedVector2Array:
	return _transform_points(_target_transform(poly).affine_inverse(), points)


func _world_holes_to_local(poly: LDObjectPolygon, holes_world: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for hole: PackedVector2Array in holes_world:
		result.append(_world_to_local(poly, hole))
	return result


func _transform_points(xform: Transform2D, points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in points:
		result.append(xform * p)
	return result


func _setup_draw_node(_node: LDPolygonBooleanDrawNode) -> void:
	pass
