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
	
	for target: LDObjectPolygon in _targets:
		if not is_instance_valid(target):
			continue
		var target_world: PackedVector2Array = _polygon_to_world(target)
		var intersection: Array = Geometry2D.intersect_polygons(target_world, accumulated)
		if intersection.is_empty():
			continue
		old_points_map[target] = target._polygon.polygon.duplicate()
		var merged: Array = Geometry2D.merge_polygons(target_world, accumulated)
		if not merged.is_empty():
			accumulated = merged[0]
			affected_targets.append(target)
	
	if affected_targets.is_empty():
		history.commit_action()
		_points = PackedVector2Array()
		get_tool_handler().select_tool("select")
		return
	
	var primary: LDObjectPolygon = affected_targets[0]
	var primary_new: PackedVector2Array = _world_to_local(primary, accumulated)
	var primary_old: PackedVector2Array = old_points_map[primary]
	var primary_obj: LDObjectPolygon = primary
	
	history.add_do(func() -> void:
		if is_instance_valid(primary_obj):
			primary_obj.modulate.a = 1.0
			primary_obj.apply_points(primary_new)
	)
	history.add_undo(func() -> void:
		if is_instance_valid(primary_obj):
			primary_obj.modulate.a = 1.0
			primary_obj.apply_points(primary_old)
	)
	primary.apply_points(primary_new)
	
	for i: int in range(1, affected_targets.size()):
		var redundant: LDObjectPolygon = affected_targets[i]
		if not is_instance_valid(redundant):
			continue
		var redundant_old: PackedVector2Array = old_points_map[redundant]
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
				redundant_obj.apply_points(redundant_old)
		)
		redundant.get_parent().remove_child(redundant)
	
	history.commit_action()
	_points = PackedVector2Array()
	get_tool_handler().select_tool("select")
