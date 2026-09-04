@warning_ignore_start("unused_parameter")
extends LDPolygonBooleanTool


func get_tool_name() -> String:
	return "PolygonAdd"


func _setup_draw_node(node: LDPolygonBooleanDrawNode) -> void:
	node.fill_color = Color(LDPalette.add_color(), 0.18)
	node.border_color = Color(LDPalette.add_color(), 0.9)


func _compute_preview_results(points: PackedVector2Array) -> Array[PackedVector2Array]:
	var accumulated: PackedVector2Array = points
	var did_merge: bool = false
	
	for target: LDObjectPolygon in _targets:
		if not is_instance_valid(target):
			continue
		var target_world: PackedVector2Array = _polygon_to_world(target)
		if Geometry2D.intersect_polygons(target_world, accumulated).is_empty():
			continue
		var merged: Array[PackedVector2Array] = Geometry2D.merge_polygons(target_world, accumulated)
		if not merged.is_empty():
			accumulated = merged.front()
			did_merge = true
	
	return [accumulated] if did_merge else []


func _compute_preview_holes(target: LDObjectPolygon, preview: PackedVector2Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	
	for t: LDObjectPolygon in _targets:
		if not is_instance_valid(t):
			continue
		var target_world: PackedVector2Array = _polygon_to_world(t)
		if Geometry2D.intersect_polygons(target_world, preview).is_empty():
			continue
		var merged: Array[PackedVector2Array] = Geometry2D.merge_polygons(target_world, preview)
		merged.remove_at(0)
		for hole_world: PackedVector2Array in _clean_pieces(merged):
			result.append(_world_to_local(target, hole_world))
		for hole_world: PackedVector2Array in _surviving_holes(t, preview):
			result.append(_world_to_local(target, hole_world))
	
	return result


## What is left of [param poly]'s own holes once [param cut] has been filled in over them, in
## world space. A hole the cut misses entirely survives whole.
func _surviving_holes(poly: LDObjectPolygon, cut: PackedVector2Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for hole_world: PackedVector2Array in _holes_to_world(poly):
		if Geometry2D.intersect_polygons(hole_world, cut).is_empty():
			result.append(hole_world)
			continue
		result.append_array(_clean_pieces(Geometry2D.clip_polygons(hole_world, cut)))
	return result


func _get_results_for_target(results: Array[PackedVector2Array], target_world: PackedVector2Array) -> Array[PackedVector2Array]:
	return [] if results.is_empty() else [results.front()]


func _commit() -> void:
	if _points.size() < 3:
		return
	
	var accumulated: PackedVector2Array = _points
	var affected: Array[LDObjectPolygon] = []
	var old_points: Dictionary[LDObjectPolygon, PackedVector2Array] = {}
	var old_holes: Dictionary[LDObjectPolygon, Array] = {}
	var merge_holes_world: Array[PackedVector2Array] = []
	
	for target: LDObjectPolygon in _targets:
		if not is_instance_valid(target):
			continue
		var target_world: PackedVector2Array = _polygon_to_world(target)
		if Geometry2D.intersect_polygons(target_world, accumulated).is_empty():
			continue
		var merged: Array[PackedVector2Array] = Geometry2D.merge_polygons(target_world, accumulated)
		if merged.is_empty():
			continue
		old_points.set(target, target.get_outer_points().duplicate())
		old_holes.set(target, target.get_holes().duplicate())
		accumulated = merged.front()
		affected.append(target)
		merged.remove_at(0)
		merge_holes_world.append_array(_clean_pieces(merged))
	
	if affected.is_empty():
		_points = PackedVector2Array()
		get_tool_handler().select_tool("select")
		return
	
	var primary: LDObjectPolygon = affected.front()
	var new_holes_world: Array[PackedVector2Array] = merge_holes_world.duplicate()
	for target: LDObjectPolygon in affected:
		new_holes_world.append_array(_surviving_holes(target, _points))
	
	var primary_new: PackedVector2Array = _world_to_local(primary, accumulated)
	var primary_new_holes: Array[PackedVector2Array] = _world_holes_to_local(primary, new_holes_world)
	var primary_old: PackedVector2Array = old_points.get(primary)
	var primary_old_holes: Array[PackedVector2Array] = old_holes.get(primary)
	
	var redundant: Array[LDObject] = []
	var redundant_undos: Array[Callable] = []
	
	for i: int in range(1, affected.size()):
		var obj: LDObjectPolygon = affected.get(i)
		var parent: Node = obj.get_parent()
		var obj_old: PackedVector2Array = old_points.get(obj)
		var obj_old_holes: Array[PackedVector2Array] = old_holes.get(obj)
		redundant.append(obj)
		redundant_undos.append(func() -> void:
			if is_instance_valid(obj) and not obj.is_inside_tree():
				parent.add_child(obj)
				_reshape(obj, obj_old, obj_old_holes)
		)
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.push("Polygon Add",
		func() -> void:
			_reshape(primary, primary_new, primary_new_holes)
			for obj: LDObject in redundant:
				if is_instance_valid(obj) and obj.is_inside_tree():
					obj.get_parent().remove_child(obj)
			_prune_selection(),
		func() -> void:
			_reshape(primary, primary_old, primary_old_holes)
			for undo: Callable in redundant_undos:
				undo.call()
	)
	history.track_detached(redundant)
	
	_points = PackedVector2Array()
	get_tool_handler().select_tool("select")
