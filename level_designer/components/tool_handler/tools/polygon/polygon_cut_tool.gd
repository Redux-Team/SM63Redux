extends LDPolygonBooleanTool


func get_tool_name() -> String:
	return "PolygonCut"


func _setup_draw_node(node: LDPolygonBooleanDrawNode) -> void:
	node.fill_color = Color(1.0, 0.2, 0.2, 0.2)
	node.border_color = Color(1.0, 0.3, 0.3, 0.9)


func _compute_preview_results(points: PackedVector2Array) -> Array[PackedVector2Array]:
	var all_results: Array[PackedVector2Array] = []
	for target: LDObjectPolygon in _targets:
		if not is_instance_valid(target):
			continue
		var target_world: PackedVector2Array = _polygon_to_world(target)
		var intersection: Array = Geometry2D.intersect_polygons(target_world, points)
		var fully_inside: bool = _is_cut_fully_inside(target_world, points)
		if intersection.is_empty() and not fully_inside:
			all_results.append(target_world)
			continue
		if fully_inside:
			var excluded: Array = Geometry2D.exclude_polygons(target_world, points)
			if not excluded.is_empty():
				all_results.append(excluded[0])
			else:
				all_results.append(target_world)
			continue
		var clipped: Array = Geometry2D.clip_polygons(target_world, points)
		if clipped.is_empty():
			all_results.append(PackedVector2Array())
			continue
		for piece: Variant in clipped:
			if piece is PackedVector2Array and (piece as PackedVector2Array).size() >= 3:
				all_results.append(piece)
	return all_results

@warning_ignore("unused_parameter")
func _get_results_for_target(results: Array[PackedVector2Array], start_idx: int, target_world: PackedVector2Array) -> Array[PackedVector2Array]:
	var preview: PackedVector2Array = _points.duplicate()
	if _cursor_pos != Vector2.ZERO and (preview.is_empty() or preview[preview.size() - 1] != _cursor_pos):
		preview.append(_cursor_pos)
	
	var pieces: Array[PackedVector2Array] = []
	
	if _is_cut_fully_inside(target_world, preview):
		var excluded: Array = Geometry2D.exclude_polygons(target_world, preview)
		for piece: Variant in excluded:
			if piece is PackedVector2Array and (piece as PackedVector2Array).size() >= 3:
				pieces.append(piece)
		return pieces
	
	var clipped: Array = Geometry2D.clip_polygons(target_world, preview)
	for piece: Variant in clipped:
		if piece is PackedVector2Array and (piece as PackedVector2Array).size() >= 3:
			pieces.append(piece)
	return pieces


func _commit() -> void:
	if _points.size() < 3:
		return
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Polygon Cut")
	
	for target: LDObjectPolygon in _targets:
		if not is_instance_valid(target):
			continue
		
		var target_world: PackedVector2Array = _polygon_to_world(target)
		var intersection: Array = Geometry2D.intersect_polygons(target_world, _points)
		var fully_inside: bool = _is_cut_fully_inside(target_world, _points)
		if intersection.is_empty() and not fully_inside:
			continue
		
		var old_pts: PackedVector2Array = target._polygon.polygon.duplicate()
		var obj: LDObjectPolygon = target
		var parent: Node = target.get_parent()
		
		if fully_inside:
			var hole_local: PackedVector2Array = _world_to_local(target, _points)
			var pre_hole_pts: PackedVector2Array = target.get_outer_points().duplicate()
			var pre_hole_holes: Array[PackedVector2Array] = target.get_holes().duplicate()
			var obj_hole: LDObjectPolygon = target
			
			history.add_do(func() -> void:
				if is_instance_valid(obj_hole):
					obj_hole.modulate.a = 1.0
					obj_hole.add_hole(hole_local)
			)
			history.add_undo(func() -> void:
				if is_instance_valid(obj_hole):
					obj_hole.modulate.a = 1.0
					obj_hole.apply_points(pre_hole_pts)
					for h: PackedVector2Array in pre_hole_holes:
						obj_hole.add_hole(h)
			)
			target.add_hole(hole_local)
			continue
		
		var clipped: Array = Geometry2D.clip_polygons(target_world, _points)
		
		if clipped.is_empty():
			history.add_do(func() -> void:
				if is_instance_valid(obj) and obj.is_inside_tree():
					obj.get_parent().remove_child(obj)
			)
			history.add_undo(func() -> void:
				if is_instance_valid(obj) and not obj.is_inside_tree():
					parent.add_child(obj)
					obj.modulate.a = 1.0
					obj.apply_points(old_pts)
			)
			target.get_parent().remove_child(target)
			continue
		
		var first_local: PackedVector2Array = _world_to_local(target, clipped[0])
		history.add_do(func() -> void:
			if is_instance_valid(obj):
				obj.modulate.a = 1.0
				obj.apply_points(first_local)
		)
		history.add_undo(func() -> void:
			if is_instance_valid(obj):
				obj.modulate.a = 1.0
				obj.apply_points(old_pts)
		)
		target.apply_points(first_local)
		
		var game_object: GameObject = GameObjectDB.get_db().find_game_object(target.source_object_id)
		var layer_id: String = "a0r0"
		if target.get_parent() is LDLayer:
			layer_id = (target.get_parent() as LDLayer).layer_id
		
		for i: int in range(1, clipped.size()):
			var piece: Variant = clipped[i]
			if not piece is PackedVector2Array or (piece as PackedVector2Array).size() < 3:
				continue
			if not game_object or not game_object.ld_editor_instance:
				continue
			
			var new_instance: LDObject = game_object.ld_editor_instance.instantiate() as LDObject
			if not new_instance is LDObjectPolygon:
				new_instance.queue_free()
				continue
			
			var new_poly: LDObjectPolygon = new_instance as LDObjectPolygon
			var centroid: Vector2 = Vector2.ZERO
			for p: Vector2 in (piece as PackedVector2Array):
				centroid += p
			centroid = (centroid / (piece as PackedVector2Array).size()).snapped(Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE))
			
			var piece_local: PackedVector2Array = PackedVector2Array()
			for p: Vector2 in (piece as PackedVector2Array):
				piece_local.append(p - centroid)
			
			viewport.add_object(new_poly, Vector2i(centroid), layer_id)
			new_poly.init_properties(game_object)
			new_poly.apply_points(piece_local)
			new_poly.place()
			
			history.add_do(func() -> void:
				if is_instance_valid(new_poly) and not new_poly.is_inside_tree():
					parent.add_child(new_poly)
			)
			history.add_undo(func() -> void:
				if is_instance_valid(new_poly) and new_poly.is_inside_tree():
					new_poly.get_parent().remove_child(new_poly)
			)
	
	history.commit_action()
	_points = PackedVector2Array()
	get_tool_handler().select_tool("select")


func _is_cut_fully_inside(target: PackedVector2Array, cut: PackedVector2Array) -> bool:
	for p: Vector2 in cut:
		if not Geometry2D.is_point_in_polygon(p, target):
			return false
	return true
