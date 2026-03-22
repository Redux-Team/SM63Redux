extends LDPolygonBooleanTool


func get_tool_name() -> String:
	return "PolygonAdd"


func _setup_draw_node(node: LDPolygonBooleanDrawNode) -> void:
	node.fill_color = Color(0.2, 0.8, 0.4, 0.2)
	node.border_color = Color(0.2, 0.9, 0.4, 0.9)


func _compute_preview_results(points: PackedVector2Array) -> Array[PackedVector2Array]:
	var accumulated: PackedVector2Array = points
	var did_merge: bool = false
	
	for target: LDObjectPolygon in _targets:
		if not is_instance_valid(target):
			continue
		var target_world: PackedVector2Array = _polygon_to_world(target)
		var intersection: Array = Geometry2D.intersect_polygons(target_world, accumulated)
		if intersection.is_empty():
			continue
		var merged: Array = Geometry2D.merge_polygons(target_world, accumulated)
		if not merged.is_empty():
			accumulated = merged[0]
			did_merge = true
	
	if not did_merge:
		return []
	return [accumulated]


func _compute_preview_holes(target: LDObjectPolygon, preview: PackedVector2Array, piece_index: int) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	
	for t: LDObjectPolygon in _targets:
		if not is_instance_valid(t):
			continue
		var tw: PackedVector2Array = _polygon_to_world(t)
		var intersection: Array = Geometry2D.intersect_polygons(tw, preview)
		if intersection.is_empty():
			continue
		var merged: Array = Geometry2D.merge_polygons(tw, preview)
		for mi: int in range(1, merged.size()):
			var hole_pts: PackedVector2Array = merged[mi]
			if hole_pts.size() >= 3:
				result.append(_world_to_local(target, TerrainPolygon.clean_polygon(hole_pts)))
	
	for t: LDObjectPolygon in _targets:
		if not is_instance_valid(t):
			continue
		var tw: PackedVector2Array = _polygon_to_world(t)
		var intersection: Array = Geometry2D.intersect_polygons(tw, preview)
		if intersection.is_empty():
			continue
		for hole: PackedVector2Array in t.get_holes():
			var hole_world: PackedVector2Array = _local_to_world(t, hole)
			var hole_covered: Array = Geometry2D.intersect_polygons(hole_world, preview)
			if hole_covered.is_empty():
				result.append(_world_to_local(target, hole_world))
				continue
			var hole_remaining: Array = Geometry2D.clip_polygons(hole_world, preview)
			for piece: Variant in hole_remaining:
				if piece is PackedVector2Array and (piece as PackedVector2Array).size() >= 3:
					result.append(_world_to_local(target, piece))
	
	return result


func _get_results_for_target(results: Array[PackedVector2Array], start_idx: int, target_world: PackedVector2Array) -> Array[PackedVector2Array]:
	if results.is_empty():
		return []
	return [results[0]]


func _commit() -> void:
	if _points.size() < 3:
		return
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Polygon Add")
	
	var accumulated: PackedVector2Array = _points
	var affected_targets: Array[LDObjectPolygon] = []
	var old_points_map: Dictionary = {}
	var old_holes_map: Dictionary = {}
	var old_meta_map: Dictionary = {}
	var new_holes_from_merge: Array[PackedVector2Array] = []
	
	for target: LDObjectPolygon in _targets:
		if not is_instance_valid(target):
			continue
		var target_world: PackedVector2Array = _polygon_to_world(target)
		var intersection: Array = Geometry2D.intersect_polygons(target_world, accumulated)
		if intersection.is_empty():
			continue
		old_points_map[target] = target.get_outer_points().duplicate()
		old_holes_map[target] = target.get_holes().duplicate()
		old_meta_map[target] = LDCurveUtil.snapshot_meta(target)
		var merged: Array = Geometry2D.merge_polygons(target_world, accumulated)
		if merged.is_empty():
			continue
		accumulated = merged[0]
		affected_targets.append(target)
		for mi: int in range(1, merged.size()):
			var hole_pts: PackedVector2Array = merged[mi]
			if hole_pts.size() >= 3:
				new_holes_from_merge.append(hole_pts)
	
	if affected_targets.is_empty():
		history.commit_action()
		_points = PackedVector2Array()
		get_tool_handler().select_tool("select")
		return
	
	var primary: LDObjectPolygon = affected_targets[0]
	var primary_new: PackedVector2Array = _world_to_local(primary, accumulated)
	var primary_old: PackedVector2Array = old_points_map[primary]
	var primary_old_holes: Array[PackedVector2Array] = old_holes_map[primary]
	var primary_old_meta: Dictionary = old_meta_map[primary]
	var primary_obj: LDObjectPolygon = primary
	
	var new_holes: Array[PackedVector2Array] = []
	
	for hole_world: PackedVector2Array in new_holes_from_merge:
		var cleaned: PackedVector2Array = TerrainPolygon.clean_polygon(hole_world)
		if cleaned.size() >= 3:
			new_holes.append(_world_to_local(primary, cleaned))
	
	for hole: PackedVector2Array in primary_old_holes:
		var hole_world: PackedVector2Array = _local_to_world(primary, hole)
		var hole_covered: Array = Geometry2D.intersect_polygons(hole_world, _points)
		if hole_covered.is_empty():
			new_holes.append(hole)
			continue
		var hole_remaining: Array = Geometry2D.clip_polygons(hole_world, _points)
		for piece: Variant in hole_remaining:
			if piece is PackedVector2Array and (piece as PackedVector2Array).size() >= 3:
				new_holes.append(_world_to_local(primary, piece))
	
	for i: int in range(1, affected_targets.size()):
		var redundant: LDObjectPolygon = affected_targets[i]
		if not is_instance_valid(redundant):
			continue
		for hole: PackedVector2Array in (old_holes_map[redundant] as Array[PackedVector2Array]):
			var hole_world: PackedVector2Array = _local_to_world(redundant, hole)
			var hole_covered: Array = Geometry2D.intersect_polygons(hole_world, _points)
			if hole_covered.is_empty():
				new_holes.append(_world_to_local(primary, hole_world))
				continue
			var hole_remaining: Array = Geometry2D.clip_polygons(hole_world, _points)
			for piece: Variant in hole_remaining:
				if piece is PackedVector2Array and (piece as PackedVector2Array).size() >= 3:
					new_holes.append(_world_to_local(primary, piece))
	
	var xform_inv_p: Transform2D = primary.get_global_transform().affine_inverse()
	var cut_local_p: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in _points:
		cut_local_p.append(xform_inv_p * p)
	var ctrl_outer_p: PackedVector2Array = PackedVector2Array(primary_old_meta.get("ctrl_outer", primary_old)) if not primary_old_meta.is_empty() else primary_old
	var affected_p: PackedInt32Array = LDCurveUtil.get_affected_outer_segments(ctrl_outer_p, primary_old_meta, cut_local_p)
	var new_meta: Dictionary = LDCurveUtil.selective_bake_meta(primary_new, primary_old_meta, ctrl_outer_p, affected_p, true)
	
	history.add_do(func() -> void:
		if is_instance_valid(primary_obj):
			primary_obj.modulate.a = 1.0
			primary_obj.clear_holes()
			primary_obj.apply_points_raw(primary_new, new_holes)
			LDCurveUtil.restore_meta(primary_obj, new_meta)
	)
	history.add_undo(func() -> void:
		if is_instance_valid(primary_obj):
			primary_obj.modulate.a = 1.0
			primary_obj.clear_holes()
			primary_obj.apply_points_raw(primary_old, primary_old_holes)
			LDCurveUtil.restore_meta(primary_obj, primary_old_meta)
	)
	primary_obj.clear_holes()
	primary_obj.apply_points_raw(primary_new, new_holes)
	LDCurveUtil.restore_meta(primary_obj, new_meta)
	
	for i: int in range(1, affected_targets.size()):
		var redundant: LDObjectPolygon = affected_targets[i]
		if not is_instance_valid(redundant):
			continue
		var redundant_old: PackedVector2Array = old_points_map[redundant]
		var redundant_old_holes: Array[PackedVector2Array] = old_holes_map[redundant]
		var redundant_old_meta: Dictionary = old_meta_map[redundant]
		var redundant_parent: Node = redundant.get_parent()
		var redundant_obj: LDObjectPolygon = redundant
		history.add_do(func() -> void:
			if is_instance_valid(redundant_obj) and redundant_obj.is_inside_tree():
				redundant_obj.get_parent().remove_child(redundant_obj)
		)
		history.add_undo(func() -> void:
			if is_instance_valid(redundant_obj) and not redundant_obj.is_inside_tree():
				redundant_parent.add_child(redundant_obj)
				redundant_obj.modulate.a = 1.0
				redundant_obj.clear_holes()
				redundant_obj.apply_points_raw(redundant_old, redundant_old_holes)
				LDCurveUtil.restore_meta(redundant_obj, redundant_old_meta)
		)
		redundant.get_parent().remove_child(redundant)
	
	history.commit_action()
	_points = PackedVector2Array()
	get_tool_handler().select_tool("select")
