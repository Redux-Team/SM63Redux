@warning_ignore_start("unused_parameter")
extends LDPolygonBooleanTool


enum CutCase {
	OUTSIDE, # cut doesn't affect the polygon
	SLICE, # cut removes a chunk from the outer polygon
	HOLE, # cut creates a new hole inside the polygon
	BRIDGE, # cut connects/merges two holes together
	REMOVE_HOLE,  # cut removes an existing hole
	EXPAND_HOLE # cut fully encapsulates an existing hole, making it bigger
}


func get_tool_name() -> String:
	return "PolygonCut"


func _setup_draw_node(node: LDPolygonBooleanDrawNode) -> void:
	node.fill_color = Color(LDPalette.danger(), 0.18)
	node.border_color = Color(LDPalette.danger(), 0.9)


func _classify_cut(target: LDObjectPolygon, cut: PackedVector2Array) -> CutCase:
	var target_world: PackedVector2Array = _polygon_to_world(target)
	if Geometry2D.intersect_polygons(target_world, cut).is_empty():
		return CutCase.OUTSIDE
	
	var holes_world: Array[PackedVector2Array] = _holes_to_world(target)
	var stays_inside: bool = _is_cut_fully_inside(target_world, cut)
	var hit_holes: Array[int] = []
	for i: int in holes_world.size():
		if not Geometry2D.intersect_polygons(holes_world.get(i), cut).is_empty():
			hit_holes.append(i)
	
	if hit_holes.size() >= 2:
		return CutCase.BRIDGE if stays_inside else CutCase.REMOVE_HOLE
	
	if hit_holes.size() == 1:
		var hole_world: PackedVector2Array = holes_world.get(hit_holes.front())
		if _is_cut_fully_inside(hole_world, cut):
			return CutCase.OUTSIDE
		if _is_cut_fully_inside(cut, hole_world):
			return CutCase.EXPAND_HOLE if stays_inside else CutCase.REMOVE_HOLE
		return CutCase.BRIDGE if stays_inside else CutCase.REMOVE_HOLE
	
	if not stays_inside:
		return CutCase.SLICE
	
	for hole_world: PackedVector2Array in holes_world:
		if _is_cut_fully_inside(hole_world, cut):
			return CutCase.OUTSIDE
	
	return CutCase.HOLE


## Whether the case leaves the outer ring exactly as it was, so only the holes change.
func _keeps_outer(cut_case: CutCase) -> bool:
	return cut_case == CutCase.HOLE or cut_case == CutCase.BRIDGE or cut_case == CutCase.EXPAND_HOLE


## The outer rings the cut leaves behind on one target, in world space. Empty means the cut wipes
## the target out; more than one entry means it falls apart into separate polygons.
func _cut_pieces(target: LDObjectPolygon, cut: PackedVector2Array, cut_case: CutCase) -> Array[PackedVector2Array]:
	var target_world: PackedVector2Array = _polygon_to_world(target)
	
	if _keeps_outer(cut_case):
		return [target_world]
	
	if cut_case == CutCase.SLICE:
		return _clean_pieces(Geometry2D.clip_polygons(target_world, cut))
	
	if cut_case == CutCase.REMOVE_HOLE:
		var untouched: Array[int] = []
		var combined: PackedVector2Array = _absorb_holes(_holes_to_world(target), cut, untouched)
		return _clean_pieces(Geometry2D.clip_polygons(target_world, combined))
	
	return []


## The holes one resulting piece ends up with, in world space. [param piece_world] scopes the
## result to that piece; pass an empty ring to get every hole the cut leaves behind.
func _holes_after_cut(target: LDObjectPolygon, cut: PackedVector2Array, cut_case: CutCase, piece_world: PackedVector2Array) -> Array[PackedVector2Array]:
	var holes_world: Array[PackedVector2Array] = _holes_to_world(target)
	var result: Array[PackedVector2Array] = []
	
	match cut_case:
		CutCase.OUTSIDE:
			return holes_world
		
		CutCase.HOLE:
			result.append_array(holes_world)
			result.append(cut)
		
		CutCase.SLICE:
			for hole_world: PackedVector2Array in holes_world:
				if Geometry2D.intersect_polygons(hole_world, cut).is_empty():
					if _hole_lands_in(hole_world, piece_world):
						result.append(hole_world)
					continue
				for remnant: PackedVector2Array in _clean_pieces(Geometry2D.clip_polygons(hole_world, cut)):
					if _hole_lands_in(remnant, piece_world):
						result.append(remnant)
		
		CutCase.BRIDGE:
			var untouched: Array[int] = []
			var merged_hole: PackedVector2Array = _absorb_holes(holes_world, cut, untouched)
			for i: int in untouched:
				result.append(holes_world.get(i))
			if merged_hole.size() >= 3:
				result.append(merged_hole)
		
		CutCase.REMOVE_HOLE:
			var untouched: Array[int] = []
			_absorb_holes(holes_world, cut, untouched)
			for i: int in untouched:
				var hole_world: PackedVector2Array = holes_world.get(i)
				if _hole_lands_in(hole_world, piece_world):
					result.append(hole_world)
		
		CutCase.EXPAND_HOLE:
			for hole_world: PackedVector2Array in holes_world:
				result.append(cut if not Geometry2D.intersect_polygons(hole_world, cut).is_empty() else hole_world)
	
	return result


func _hole_lands_in(hole_world: PackedVector2Array, piece_world: PackedVector2Array) -> bool:
	if piece_world.is_empty():
		return true
	return Geometry2D.is_point_in_polygon(hole_world.get(0), piece_world)


func _compute_preview_results(points: PackedVector2Array) -> Array[PackedVector2Array]:
	var all_results: Array[PackedVector2Array] = []
	for target: LDObjectPolygon in _targets:
		if not is_instance_valid(target):
			continue
		var cut_case: CutCase = _classify_cut(target, points)
		if cut_case == CutCase.OUTSIDE:
			continue
		var pieces: Array[PackedVector2Array] = _cut_pieces(target, points, cut_case)
		if pieces.is_empty():
			all_results.append(PackedVector2Array())
		else:
			all_results.append_array(pieces)
	return all_results


func _get_results_for_target(results: Array[PackedVector2Array], target_world: PackedVector2Array) -> Array[PackedVector2Array]:
	var preview: PackedVector2Array = _preview_points()
	for target: LDObjectPolygon in _targets:
		if not is_instance_valid(target) or _polygon_to_world(target) != target_world:
			continue
		var cut_case: CutCase = _classify_cut(target, preview)
		if cut_case == CutCase.OUTSIDE:
			return []
		return _cut_pieces(target, preview, cut_case)
	return []


func _compute_preview_holes_for_piece(target: LDObjectPolygon, preview: PackedVector2Array, piece_world: PackedVector2Array) -> Array[PackedVector2Array]:
	var cut_case: CutCase = _classify_cut(target, preview)
	return _world_holes_to_local(target, _holes_after_cut(target, preview, cut_case, piece_world))


func _commit() -> void:
	if _points.size() < 3:
		return
	
	var do_actions: Array[Callable] = []
	var undo_actions: Array[Callable] = []
	var detached: Array[Node] = []
	
	for target: LDObjectPolygon in _targets:
		if not is_instance_valid(target):
			continue
		var cut_case: CutCase = _classify_cut(target, _points)
		if cut_case != CutCase.OUTSIDE:
			_commit_target(target, cut_case, do_actions, undo_actions, detached)
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.push("Polygon Cut",
		func() -> void:
			for action: Callable in do_actions:
				action.call()
			_prune_selection(),
		func() -> void:
			for action: Callable in undo_actions:
				action.call()
	)
	history.track_detached(detached)
	
	_points = PackedVector2Array()
	get_tool_handler().select_tool("select")


## Turns one target's cut result into history actions: the target itself becomes the first piece,
## and every further piece becomes a new object rebased on its own centroid.
func _commit_target(target: LDObjectPolygon, cut_case: CutCase, do_actions: Array[Callable], undo_actions: Array[Callable], detached: Array[Node]) -> void:
	var old_points: PackedVector2Array = target.get_outer_points().duplicate()
	var old_holes: Array[PackedVector2Array] = target.get_holes().duplicate()
	var parent: Node = target.get_parent()
	var pieces: Array[PackedVector2Array] = _cut_pieces(target, _points, cut_case)
	
	if pieces.is_empty():
		detached.append(target)
		do_actions.append(func() -> void:
			if is_instance_valid(target) and target.is_inside_tree():
				target.get_parent().remove_child(target)
		)
		undo_actions.append(func() -> void:
			if is_instance_valid(target) and not target.is_inside_tree():
				parent.add_child(target)
				_reshape(target, old_points, old_holes)
		)
		return
	
	var piece_holes: Array[Array] = []
	for piece: PackedVector2Array in pieces:
		piece_holes.append(_holes_after_cut(target, _points, cut_case, piece))
	
	var first_points: PackedVector2Array = old_points if _keeps_outer(cut_case) else _world_to_local(target, pieces.front())
	do_actions.append(_reshape_action(target, first_points, _world_holes_to_local(target, piece_holes.front())))
	undo_actions.append(_reshape_action(target, old_points, old_holes))
	
	var game_object: GameObject = GameDB.get_object(target.source_object_id)
	if not game_object:
		return
	
	for i: int in range(1, pieces.size()):
		var piece: LDObjectPolygon = _spawn_piece(target, game_object, pieces.get(i), piece_holes.get(i))
		if not piece:
			continue
		detached.append(piece)
		do_actions.append(func() -> void:
			if is_instance_valid(piece) and not piece.is_inside_tree():
				parent.add_child(piece)
		)
		undo_actions.append(func() -> void:
			if is_instance_valid(piece) and piece.is_inside_tree():
				piece.get_parent().remove_child(piece)
		)


## Builds a fresh polygon for a piece the cut broke off, rebased so its own origin sits on the
## snapped centroid of the piece. [param holes_world] is in world space, like [param piece_world].
func _spawn_piece(target: LDObjectPolygon, game_object: GameObject, piece_world: PackedVector2Array, holes_world: Array) -> LDObjectPolygon:
	var instance: LDObject = game_object.get_editor_instance()
	var piece: LDObjectPolygon = instance as LDObjectPolygon
	if not piece:
		instance.queue_free()
		return null
	
	var snap: Vector2 = Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE)
	var centroid: Vector2 = _centroid(piece_world).snapped(snap)
	var local_holes: Array[PackedVector2Array] = []
	for hole_world: PackedVector2Array in holes_world:
		local_holes.append(_offset_points(hole_world, -centroid))
	
	LD.get_area().add_object(piece, Vector2i(centroid))
	piece.init_properties(game_object)
	piece.polygon_data = target.polygon_data
	piece.apply_points_and_holes(_offset_points(piece_world, -centroid), local_holes)
	piece.place()
	piece.set_property("position", centroid)
	return piece
