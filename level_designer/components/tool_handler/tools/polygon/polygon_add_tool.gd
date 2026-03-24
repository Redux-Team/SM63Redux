extends LDPolygonBooleanTool


func get_tool_name() -> String:
	return "PolygonAdd"


func _setup_draw_node(node: LDPolygonBooleanDrawNode) -> void:
	node.fill_color = Color(0.2, 0.8, 0.4, 0.2)
	node.border_color = Color(0.2, 0.9, 0.4, 0.9)
	node.result_fill_color = Color(0.2, 0.5, 1.0, 0.25)
	node.result_border_color = Color(0.4, 0.7, 1.0, 0.8)


func _compute_primary_piece(target: LDObjectPolygon, best: PackedVector2Array) -> PackedVector2Array:
	var target_world: PackedVector2Array = _polygon_to_world(target)
	if Geometry2D.intersect_polygons(target_world, best).is_empty():
		return PackedVector2Array()
	var merged: Array = Geometry2D.merge_polygons(target_world, best)
	if merged.is_empty():
		return PackedVector2Array()
	return merged[0]


func _compute_preview_holes(target: LDObjectPolygon, best: PackedVector2Array, old_holes: Array[LDPolygon]) -> Array[LDPolygon]:
	var new_holes: Array[LDPolygon] = []
	for old_h: LDPolygon in old_holes:
		var hw: PackedVector2Array = _local_to_world(target, old_h.to_flat())
		if Geometry2D.intersect_polygons(hw, best).is_empty():
			new_holes.append(old_h.duplicate())
			continue
		var remaining: Array = Geometry2D.clip_polygons(hw, best)
		for piece: Variant in remaining:
			if not piece is PackedVector2Array or (piece as PackedVector2Array).size() < 3:
				continue
			var lf: PackedVector2Array = _world_to_local(target, piece as PackedVector2Array)
			if lf.size() >= 3:
				new_holes.append(LDPolygon.from_flat(lf))
	return new_holes


func _commit() -> void:
	if _points.size() < 3:
		return
	_restore_targets()
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Polygon Add")
	var accumulated: PackedVector2Array = _points
	var affected: Array[LDObjectPolygon] = []
	var old_outers: Dictionary = {}
	var old_holes_map: Dictionary = {}
	for target: LDObjectPolygon in _targets:
		if not is_instance_valid(target):
			continue
		var target_world: PackedVector2Array = _polygon_to_world(target)
		if Geometry2D.intersect_polygons(target_world, accumulated).is_empty():
			continue
		old_outers[target] = target.outer.duplicate()
		old_holes_map[target] = _duplicate_holes(target.holes)
		var merged: Array = Geometry2D.merge_polygons(target_world, accumulated)
		if merged.is_empty():
			continue
		accumulated = merged[0]
		affected.append(target)
	if affected.is_empty():
		history.commit_action()
		_points = PackedVector2Array()
		_targets = []
		get_tool_handler().select_tool("select")
		return
	var primary: LDObjectPolygon = affected[0]
	var primary_old_outer: LDPolygon = old_outers[primary]
	var primary_old_holes: Array[LDPolygon] = old_holes_map[primary]
	var new_flat_local: PackedVector2Array = _world_to_local(primary, accumulated)
	var new_outer: LDPolygon = primary_old_outer.boolean_result(new_flat_local)
	var new_holes: Array[LDPolygon] = []
	var full_merged: Array = Geometry2D.merge_polygons(_polygon_to_world(primary), _points)
	for mi: int in range(1, full_merged.size()):
		var hw: PackedVector2Array = full_merged[mi]
		if hw.size() >= 3:
			var lf: PackedVector2Array = _world_to_local(primary, TerrainPolygon.clean_polygon(hw))
			if lf.size() >= 3:
				new_holes.append(LDPolygon.from_flat(lf))
	for old_h: LDPolygon in primary_old_holes:
		var hw: PackedVector2Array = _local_to_world(primary, old_h.to_flat())
		if Geometry2D.intersect_polygons(hw, _points).is_empty():
			new_holes.append(old_h.duplicate())
			continue
		var remaining: Array = Geometry2D.clip_polygons(hw, _points)
		for piece: Variant in remaining:
			if not piece is PackedVector2Array or (piece as PackedVector2Array).size() < 3:
				continue
			var lf: PackedVector2Array = _world_to_local(primary, piece)
			var matched: LDPolygon = _match_hole(primary_old_holes, lf)
			if matched != null:
				new_holes.append(matched.boolean_result(lf))
			else:
				new_holes.append(LDPolygon.from_flat(lf))
	for i: int in range(1, affected.size()):
		var redundant: LDObjectPolygon = affected[i]
		if not is_instance_valid(redundant):
			continue
		for old_h: LDPolygon in (old_holes_map[redundant] as Array[LDPolygon]):
			var hw: PackedVector2Array = _local_to_world(redundant, old_h.to_flat())
			if Geometry2D.intersect_polygons(hw, _points).is_empty():
				new_holes.append(LDPolygon.from_flat(_world_to_local(primary, hw)))
				continue
			var remaining: Array = Geometry2D.clip_polygons(hw, _points)
			for piece: Variant in remaining:
				if not piece is PackedVector2Array or (piece as PackedVector2Array).size() < 3:
					continue
				new_holes.append(LDPolygon.from_flat(_world_to_local(primary, piece)))
	var primary_obj: LDObjectPolygon = primary
	var new_outer_final: LDPolygon = new_outer
	var new_holes_final: Array[LDPolygon] = new_holes
	history.add_do(func() -> void:
		if is_instance_valid(primary_obj):
			primary_obj.modulate.a = 1.0
			primary_obj.apply_segments(new_outer_final, new_holes_final)
	)
	history.add_undo(func() -> void:
		if is_instance_valid(primary_obj):
			primary_obj.modulate.a = 1.0
			primary_obj.apply_segments(primary_old_outer, primary_old_holes)
	)
	primary_obj.apply_segments(new_outer_final, new_holes_final)
	for i: int in range(1, affected.size()):
		var redundant: LDObjectPolygon = affected[i]
		if not is_instance_valid(redundant):
			continue
		var r_old_outer: LDPolygon = old_outers[redundant]
		var r_old_holes: Array[LDPolygon] = old_holes_map[redundant]
		var r_parent: Node = redundant.get_parent()
		var r_obj: LDObjectPolygon = redundant
		history.add_do(func() -> void:
			if is_instance_valid(r_obj) and r_obj.is_inside_tree():
				r_obj.get_parent().remove_child(r_obj)
		)
		history.add_undo(func() -> void:
			if is_instance_valid(r_obj) and not r_obj.is_inside_tree():
				r_parent.add_child(r_obj)
				r_obj.modulate.a = 1.0
				r_obj.apply_segments(r_old_outer, r_old_holes)
		)
		redundant.get_parent().remove_child(redundant)
	history.commit_action()
	_points = PackedVector2Array()
	_targets = []
	get_tool_handler().select_tool("select")
