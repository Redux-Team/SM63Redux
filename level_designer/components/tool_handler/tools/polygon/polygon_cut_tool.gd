extends LDPolygonBooleanTool


enum CutCase {
	OUTSIDE,
	SLICE,
	HOLE,
	BRIDGE,
	REMOVE_HOLE,
	EXPAND_HOLE
}


func get_tool_name() -> String:
	return "PolygonCut"


func _setup_draw_node(node: LDPolygonBooleanDrawNode) -> void:
	node.fill_color = Color(1.0, 0.2, 0.2, 0.2)
	node.border_color = Color(1.0, 0.3, 0.3, 0.9)
	node.result_fill_color = Color(0.2, 0.5, 1.0, 0.25)
	node.result_border_color = Color(0.4, 0.7, 1.0, 0.8)


func _classify_cut(target: LDObjectPolygon, cut: PackedVector2Array) -> CutCase:
	var target_world: PackedVector2Array = _polygon_to_world(target)
	var intersection: Array = Geometry2D.intersect_polygons(target_world, cut)
	if intersection.is_empty():
		return CutCase.OUTSIDE
	var holes_world: Array[PackedVector2Array] = _holes_to_world(target)
	var intersected_holes: Array[int] = []
	for i: int in holes_world.size():
		if not Geometry2D.intersect_polygons(holes_world[i], cut).is_empty():
			intersected_holes.append(i)
	if intersected_holes.size() >= 2:
		for p: Vector2 in cut:
			if not Geometry2D.is_point_in_polygon(p, target_world):
				return CutCase.REMOVE_HOLE
		return CutCase.BRIDGE
	if intersected_holes.size() == 1:
		var hole_w: PackedVector2Array = holes_world[intersected_holes[0]]
		var cut_fully_inside_hole: bool = true
		for p: Vector2 in cut:
			if not Geometry2D.is_point_in_polygon(p, hole_w):
				cut_fully_inside_hole = false
				break
		if cut_fully_inside_hole:
			return CutCase.OUTSIDE
		var hole_fully_inside_cut: bool = true
		for p: Vector2 in hole_w:
			if not Geometry2D.is_point_in_polygon(p, cut):
				hole_fully_inside_cut = false
				break
		if hole_fully_inside_cut:
			var cut_inside_outer: bool = true
			for p: Vector2 in cut:
				if not Geometry2D.is_point_in_polygon(p, target_world):
					cut_inside_outer = false
					break
			return CutCase.EXPAND_HOLE if cut_inside_outer else CutCase.REMOVE_HOLE
		for p: Vector2 in cut:
			if not Geometry2D.is_point_in_polygon(p, target_world):
				return CutCase.REMOVE_HOLE
		return CutCase.BRIDGE
	var fully_inside: bool = true
	for p: Vector2 in cut:
		if not Geometry2D.is_point_in_polygon(p, target_world):
			fully_inside = false
			break
	if not fully_inside:
		return CutCase.SLICE
	for i: int in holes_world.size():
		if _is_fully_inside(holes_world[i], cut):
			return CutCase.OUTSIDE
	return CutCase.HOLE


func _compute_primary_piece(target: LDObjectPolygon, best: PackedVector2Array) -> PackedVector2Array:
	var cut_case: CutCase = _classify_cut(target, best)
	match cut_case:
		CutCase.OUTSIDE:
			return PackedVector2Array()
		CutCase.HOLE, CutCase.BRIDGE, CutCase.EXPAND_HOLE:
			return _polygon_to_world(target)
		CutCase.SLICE:
			var clipped: Array = Geometry2D.clip_polygons(_polygon_to_world(target), best)
			if clipped.is_empty() or not clipped[0] is PackedVector2Array:
				return PackedVector2Array()
			return TerrainPolygon.clean_polygon(clipped[0] as PackedVector2Array)
		CutCase.REMOVE_HOLE:
			var combined_cut: PackedVector2Array = best
			for hw: PackedVector2Array in _holes_to_world(target):
				if not Geometry2D.intersect_polygons(hw, best).is_empty():
					var merged: Array = Geometry2D.merge_polygons(hw, combined_cut)
					if not merged.is_empty():
						combined_cut = TerrainPolygon.clean_polygon(merged[0])
			var clipped: Array = Geometry2D.clip_polygons(_polygon_to_world(target), combined_cut)
			if clipped.is_empty() or not clipped[0] is PackedVector2Array:
				return PackedVector2Array()
			return TerrainPolygon.clean_polygon(clipped[0] as PackedVector2Array)
	return PackedVector2Array()


func _compute_preview_holes(target: LDObjectPolygon, best: PackedVector2Array, old_holes: Array[LDPolygon]) -> Array[LDPolygon]:
	var cut_case: CutCase = _classify_cut(target, best)
	match cut_case:
		CutCase.HOLE:
			var new_holes: Array[LDPolygon] = _duplicate_holes(old_holes)
			new_holes.append(LDPolygon.from_flat(_world_to_local(target, best)))
			return new_holes
		CutCase.BRIDGE:
			var holes_world: Array[PackedVector2Array] = _holes_to_world(target)
			var merged_hole: PackedVector2Array = best
			var new_holes: Array[LDPolygon] = []
			for i: int in holes_world.size():
				if not Geometry2D.intersect_polygons(holes_world[i], best).is_empty():
					var merged: Array = Geometry2D.merge_polygons(merged_hole, holes_world[i])
					if not merged.is_empty():
						merged_hole = TerrainPolygon.clean_polygon(merged[0])
				else:
					new_holes.append(old_holes[i].duplicate())
			var cleaned: PackedVector2Array = TerrainPolygon.clean_polygon(merged_hole)
			if cleaned.size() >= 3:
				new_holes.append(LDPolygon.from_flat(_world_to_local(target, cleaned)))
			return new_holes
		CutCase.EXPAND_HOLE:
			var new_holes: Array[LDPolygon] = []
			for i: int in old_holes.size():
				var hw: PackedVector2Array = _local_to_world(target, old_holes[i].to_flat())
				if Geometry2D.intersect_polygons(hw, best).is_empty():
					new_holes.append(old_holes[i].duplicate())
				else:
					new_holes.append(LDPolygon.from_flat(_world_to_local(target, best)))
			return new_holes
		CutCase.REMOVE_HOLE:
			var combined_cut: PackedVector2Array = best
			var surviving_holes: Array[LDPolygon] = []
			var holes_world: Array[PackedVector2Array] = _holes_to_world(target)
			for i: int in holes_world.size():
				if Geometry2D.intersect_polygons(holes_world[i], best).is_empty():
					surviving_holes.append(old_holes[i].duplicate())
					continue
				var merged: Array = Geometry2D.merge_polygons(holes_world[i], combined_cut)
				if not merged.is_empty():
					combined_cut = TerrainPolygon.clean_polygon(merged[0])
			var clipped: Array = Geometry2D.clip_polygons(_polygon_to_world(target), combined_cut)
			if clipped.is_empty() or not clipped[0] is PackedVector2Array:
				return []
			var primary_piece: PackedVector2Array = clipped[0] as PackedVector2Array
			var result: Array[LDPolygon] = []
			for sh: LDPolygon in surviving_holes:
				if Geometry2D.is_point_in_polygon(_local_to_world(target, sh.to_flat())[0], primary_piece):
					result.append(sh)
			return result
		CutCase.SLICE:
			var clipped: Array = Geometry2D.clip_polygons(_polygon_to_world(target), best)
			if clipped.is_empty() or not clipped[0] is PackedVector2Array:
				return []
			return _holes_for_piece(clipped[0] as PackedVector2Array, old_holes, target)
	return []


func _compute_extra_pieces(target: LDObjectPolygon, best: PackedVector2Array) -> Array[PackedVector2Array]:
	var cut_case: CutCase = _classify_cut(target, best)
	var result: Array[PackedVector2Array] = []
	match cut_case:
		CutCase.SLICE:
			var clipped: Array = Geometry2D.clip_polygons(_polygon_to_world(target), best)
			for i: int in range(1, clipped.size()):
				if clipped[i] is PackedVector2Array and (clipped[i] as PackedVector2Array).size() >= 3:
					result.append(TerrainPolygon.clean_polygon(clipped[i] as PackedVector2Array))
		CutCase.REMOVE_HOLE:
			var combined_cut: PackedVector2Array = best
			for hw: PackedVector2Array in _holes_to_world(target):
				if not Geometry2D.intersect_polygons(hw, best).is_empty():
					var merged: Array = Geometry2D.merge_polygons(hw, combined_cut)
					if not merged.is_empty():
						combined_cut = TerrainPolygon.clean_polygon(merged[0])
			var clipped: Array = Geometry2D.clip_polygons(_polygon_to_world(target), combined_cut)
			for i: int in range(1, clipped.size()):
				if clipped[i] is PackedVector2Array and (clipped[i] as PackedVector2Array).size() >= 3:
					result.append(TerrainPolygon.clean_polygon(clipped[i] as PackedVector2Array))
	return result


func _commit() -> void:
	if _points.size() < 3:
		return
	_restore_targets()
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Polygon Cut")
	for target: LDObjectPolygon in _targets:
		if not is_instance_valid(target):
			continue
		var cut_case: CutCase = _classify_cut(target, _points)
		if cut_case == CutCase.OUTSIDE:
			continue
		var old_outer: LDPolygon = target.outer.duplicate()
		var old_holes: Array[LDPolygon] = _duplicate_holes(target.holes)
		var obj: LDObjectPolygon = target
		var parent: Node = target.get_parent()
		match cut_case:
			CutCase.HOLE:
				var new_holes: Array[LDPolygon] = _duplicate_holes(old_holes)
				new_holes.append(LDPolygon.from_flat(_world_to_local(target, _points)))
				_apply_and_record(history, obj, parent, old_outer, old_holes, old_outer.duplicate(), new_holes)
			CutCase.BRIDGE:
				var holes_world: Array[PackedVector2Array] = _holes_to_world(target)
				var merged_hole: PackedVector2Array = _points
				var new_holes: Array[LDPolygon] = []
				for i: int in holes_world.size():
					if not Geometry2D.intersect_polygons(holes_world[i], _points).is_empty():
						var merged: Array = Geometry2D.merge_polygons(merged_hole, holes_world[i])
						if not merged.is_empty():
							merged_hole = TerrainPolygon.clean_polygon(merged[0])
					else:
						new_holes.append(old_holes[i].duplicate())
				var cleaned: PackedVector2Array = TerrainPolygon.clean_polygon(merged_hole)
				if cleaned.size() >= 3:
					new_holes.append(LDPolygon.from_flat(_world_to_local(target, cleaned)))
				_apply_and_record(history, obj, parent, old_outer, old_holes, old_outer.duplicate(), new_holes)
			CutCase.EXPAND_HOLE:
				var new_holes: Array[LDPolygon] = []
				for i: int in old_holes.size():
					var hw: PackedVector2Array = _local_to_world(target, old_holes[i].to_flat())
					if Geometry2D.intersect_polygons(hw, _points).is_empty():
						new_holes.append(old_holes[i].duplicate())
					else:
						new_holes.append(LDPolygon.from_flat(_world_to_local(target, _points)))
				_apply_and_record(history, obj, parent, old_outer, old_holes, old_outer.duplicate(), new_holes)
			CutCase.REMOVE_HOLE:
				_commit_remove_hole(target, obj, parent, old_outer, old_holes, history)
			CutCase.SLICE:
				_commit_slice(target, obj, parent, old_outer, old_holes, history)
	history.commit_action()
	_points = PackedVector2Array()
	get_tool_handler().select_tool("select")


func _apply_and_record(
	history: LDHistoryHandler,
	obj: LDObjectPolygon,
	parent: Node,
	old_outer: LDPolygon,
	old_holes: Array[LDPolygon],
	new_outer: LDPolygon,
	new_holes: Array[LDPolygon]
) -> void:
	history.add_do(func() -> void:
		if is_instance_valid(obj):
			obj.modulate.a = 1.0
			obj.apply_segments(new_outer, new_holes)
	)
	history.add_undo(func() -> void:
		if is_instance_valid(obj):
			obj.modulate.a = 1.0
			obj.apply_segments(old_outer, old_holes)
	)
	obj.apply_segments(new_outer, new_holes)


func _commit_remove_hole(
	target: LDObjectPolygon,
	obj: LDObjectPolygon,
	parent: Node,
	old_outer: LDPolygon,
	old_holes: Array[LDPolygon],
	history: LDHistoryHandler
) -> void:
	var holes_world: Array[PackedVector2Array] = _holes_to_world(target)
	var target_world: PackedVector2Array = _polygon_to_world(target)
	var combined_cut: PackedVector2Array = _points
	var surviving_holes: Array[LDPolygon] = []
	for i: int in holes_world.size():
		if Geometry2D.intersect_polygons(holes_world[i], _points).is_empty():
			surviving_holes.append(old_holes[i].duplicate())
			continue
		var merged: Array = Geometry2D.merge_polygons(holes_world[i], combined_cut)
		if not merged.is_empty():
			combined_cut = TerrainPolygon.clean_polygon(merged[0])
	var clipped: Array = Geometry2D.clip_polygons(target_world, combined_cut)
	if clipped.is_empty():
		history.add_do(func() -> void:
			if is_instance_valid(obj) and obj.is_inside_tree():
				obj.get_parent().remove_child(obj)
		)
		history.add_undo(func() -> void:
			if is_instance_valid(obj) and not obj.is_inside_tree():
				parent.add_child(obj)
				obj.modulate.a = 1.0
				obj.apply_segments(old_outer, old_holes)
		)
		target.get_parent().remove_child(target)
		return
	var new_flat_local: PackedVector2Array = _world_to_local(target, TerrainPolygon.clean_polygon(clipped[0]))
	var new_outer: LDPolygon = old_outer.boolean_result(new_flat_local)
	var first_holes: Array[LDPolygon] = []
	for sh: LDPolygon in surviving_holes:
		if Geometry2D.is_point_in_polygon(_local_to_world(target, sh.to_flat())[0], clipped[0]):
			first_holes.append(sh)
	_apply_and_record(history, obj, parent, old_outer, old_holes, new_outer, first_holes)
	_spawn_extra_pieces(clipped, 1, surviving_holes, target, parent, old_outer, old_holes, history)


func _commit_slice(
	target: LDObjectPolygon,
	obj: LDObjectPolygon,
	parent: Node,
	old_outer: LDPolygon,
	old_holes: Array[LDPolygon],
	history: LDHistoryHandler
) -> void:
	var clipped: Array = Geometry2D.clip_polygons(_polygon_to_world(target), _points)
	if clipped.is_empty():
		history.add_do(func() -> void:
			if is_instance_valid(obj) and obj.is_inside_tree():
				obj.get_parent().remove_child(obj)
		)
		history.add_undo(func() -> void:
			if is_instance_valid(obj) and not obj.is_inside_tree():
				parent.add_child(obj)
				obj.modulate.a = 1.0
				obj.apply_segments(old_outer, old_holes)
		)
		target.get_parent().remove_child(target)
		return
	var first_flat: PackedVector2Array = _world_to_local(target, TerrainPolygon.clean_polygon(clipped[0]))
	var new_outer: LDPolygon = old_outer.boolean_result(first_flat)
	var first_holes: Array[LDPolygon] = _holes_for_piece(clipped[0], old_holes, target)
	_apply_and_record(history, obj, parent, old_outer, old_holes, new_outer, first_holes)
	_spawn_extra_pieces(clipped, 1, old_holes, target, parent, old_outer, old_holes, history)


func _holes_for_piece(piece_world: PackedVector2Array, old_holes: Array[LDPolygon], target: LDObjectPolygon) -> Array[LDPolygon]:
	var result: Array[LDPolygon] = []
	for old_h: LDPolygon in old_holes:
		var hw: PackedVector2Array = _local_to_world(target, old_h.to_flat())
		if Geometry2D.intersect_polygons(hw, _points).is_empty():
			if Geometry2D.is_point_in_polygon(hw[0], piece_world):
				result.append(old_h.duplicate())
			continue
		var remaining: Array = Geometry2D.clip_polygons(hw, _points)
		for piece: Variant in remaining:
			if not piece is PackedVector2Array or (piece as PackedVector2Array).size() < 3:
				continue
			var cleaned: PackedVector2Array = TerrainPolygon.clean_polygon(piece)
			if cleaned.size() < 3 or not Geometry2D.is_point_in_polygon(cleaned[0], piece_world):
				continue
			var lf: PackedVector2Array = _world_to_local(target, cleaned)
			var matched: LDPolygon = _match_hole(old_holes, lf)
			if matched != null:
				result.append(matched.boolean_result(lf))
			else:
				result.append(LDPolygon.from_flat(lf))
	return result


func _spawn_extra_pieces(
	clipped: Array,
	start_idx: int,
	available_holes: Array[LDPolygon],
	target: LDObjectPolygon,
	parent: Node,
	old_outer: LDPolygon,
	old_holes: Array[LDPolygon],
	history: LDHistoryHandler
) -> void:
	var game_object: GameObject = GameObjectDB.get_db().find_game_object(target.source_object_id)
	var layer_id: String = "a0r0"
	if target.get_parent() is LDLayer:
		layer_id = (target.get_parent() as LDLayer).layer_id
	
	var target_xform: Transform2D = viewport.get_root().get_global_transform().affine_inverse() * target.get_global_transform()
	var inv_target_xform: Transform2D = target_xform.affine_inverse()
	
	for ci: int in range(start_idx, clipped.size()):
		var piece: Variant = clipped[ci]
		if not piece is PackedVector2Array or (piece as PackedVector2Array).size() < 3:
			continue
		if not game_object or not game_object.ld_editor_instance:
			continue
		var new_instance: LDObject = game_object.ld_editor_instance.instantiate() as LDObject
		if not new_instance is LDObjectPolygon:
			new_instance.queue_free()
			continue
		var new_poly: LDObjectPolygon = new_instance as LDObjectPolygon
		var piece_cleaned: PackedVector2Array = TerrainPolygon.clean_polygon(piece)
		var centroid: Vector2 = Vector2.ZERO
		for p: Vector2 in piece_cleaned:
			centroid += p
		centroid = (centroid / piece_cleaned.size()).snapped(Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE))
		
		var piece_old_local: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in piece_cleaned:
			piece_old_local.append(inv_target_xform * p)
		
		var piece_outer_old_local: LDPolygon = old_outer.boolean_result(piece_old_local)
		var piece_outer: LDPolygon = LDPolygon.new()
		for seg: LDSegment in piece_outer_old_local.segments:
			var seg_world: Vector2 = target_xform * seg.point
			var new_seg: LDSegment = LDSegment.new(seg_world - centroid, seg.is_curve)
			new_seg.handle_in = target_xform.basis_xform(seg.handle_in)
			new_seg.handle_out = target_xform.basis_xform(seg.handle_out)
			piece_outer.segments.append(new_seg)
		
		var piece_holes: Array[LDPolygon] = []
		for sh: LDPolygon in available_holes:
			var shw: PackedVector2Array = _local_to_world(target, sh.to_flat())
			if not Geometry2D.is_point_in_polygon(shw[0], piece_cleaned):
				continue
			var new_hole: LDPolygon = LDPolygon.new()
			for seg: LDSegment in sh.segments:
				var seg_world: Vector2 = target_xform * seg.point
				var new_seg: LDSegment = LDSegment.new(seg_world - centroid, seg.is_curve)
				new_seg.handle_in = target_xform.basis_xform(seg.handle_in)
				new_seg.handle_out = target_xform.basis_xform(seg.handle_out)
				new_hole.segments.append(new_seg)
			piece_holes.append(new_hole)
		
		viewport.add_object(new_poly, Vector2i(centroid), layer_id)
		new_poly.init_properties(game_object)
		new_poly.apply_segments(piece_outer, piece_holes)
		new_poly.place()
		
		history.add_do(func() -> void:
			if is_instance_valid(new_poly) and not new_poly.is_inside_tree():
				parent.add_child(new_poly)
		)
		history.add_undo(func() -> void:
			if is_instance_valid(new_poly) and new_poly.is_inside_tree():
				new_poly.get_parent().remove_child(new_poly)
		)


func _is_fully_inside(container: PackedVector2Array, points: PackedVector2Array) -> bool:
	for p: Vector2 in points:
		if not Geometry2D.is_point_in_polygon(p, container):
			return false
	return true
