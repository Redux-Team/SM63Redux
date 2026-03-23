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


func _classify_cut(target: LDObjectPolygon, cut: PackedVector2Array) -> CutCase:
	var target_world: PackedVector2Array = _polygon_to_world(target)
	var intersection: Array = Geometry2D.intersect_polygons(target_world, cut)
	
	if intersection.is_empty():
		return CutCase.OUTSIDE
	
	var holes_world: Array[PackedVector2Array] = _holes_to_world(target)
	
	var intersected_holes: Array[int] = []
	for i: int in holes_world.size():
		var hole_intersection: Array = Geometry2D.intersect_polygons(holes_world[i], cut)
		if not hole_intersection.is_empty():
			intersected_holes.append(i)
	
	if intersected_holes.size() >= 2:
		var all_exit_outer: bool = false
		for p: Vector2 in cut:
			if not Geometry2D.is_point_in_polygon(p, target_world):
				all_exit_outer = true
				break
		if all_exit_outer:
			return CutCase.REMOVE_HOLE
		return CutCase.BRIDGE
	
	if intersected_holes.size() == 1:
		var hole_idx: int = intersected_holes[0]
		var hole_w: PackedVector2Array = holes_world[hole_idx]
		
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
			var cut_fully_inside_outer: bool = true
			for p: Vector2 in cut:
				if not Geometry2D.is_point_in_polygon(p, target_world):
					cut_fully_inside_outer = false
					break
			return CutCase.EXPAND_HOLE if cut_fully_inside_outer else CutCase.REMOVE_HOLE
		
		var cut_exits_outer: bool = false
		for p: Vector2 in cut:
			if not Geometry2D.is_point_in_polygon(p, target_world):
				cut_exits_outer = true
				break
		if cut_exits_outer:
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
		if _is_cut_fully_inside(holes_world[i], cut):
			return CutCase.OUTSIDE
	
	return CutCase.HOLE


func _compute_preview_holes_for_piece(target: LDObjectPolygon, preview: PackedVector2Array, piece_world: PackedVector2Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var cut_case: CutCase = _classify_cut(target, preview)
	
	match cut_case:
		CutCase.SLICE:
			for hole: PackedVector2Array in target.get_holes():
				var hole_world: PackedVector2Array = _local_to_world(target, hole)
				var hole_in_cut: Array = Geometry2D.intersect_polygons(hole_world, preview)
				if not hole_in_cut.is_empty():
					var hole_remaining: Array = Geometry2D.clip_polygons(hole_world, preview)
					for piece: Variant in hole_remaining:
						if not piece is PackedVector2Array or (piece as PackedVector2Array).size() < 3:
							continue
						var cleaned: PackedVector2Array = TerrainPolygon.clean_polygon(piece)
						if cleaned.size() < 3:
							continue
						if not Geometry2D.intersect_polygons(cleaned, piece_world).is_empty():
							result.append(_world_to_local(target, cleaned))
				else:
					if not Geometry2D.intersect_polygons(hole_world, piece_world).is_empty():
						result.append(hole)
		CutCase.REMOVE_HOLE:
			var holes_world: Array[PackedVector2Array] = _holes_to_world(target)
			var combined_cut: PackedVector2Array = preview
			var surviving_holes_world: Array[PackedVector2Array] = []
			for i: int in holes_world.size():
				var hole_intersection: Array = Geometry2D.intersect_polygons(holes_world[i], preview)
				if hole_intersection.is_empty():
					surviving_holes_world.append(holes_world[i])
					continue
				var merged: Array = Geometry2D.merge_polygons(holes_world[i], combined_cut)
				if not merged.is_empty():
					combined_cut = TerrainPolygon.clean_polygon(merged[0])
			for hw: PackedVector2Array in surviving_holes_world:
				if not Geometry2D.intersect_polygons(hw, piece_world).is_empty():
					result.append(_world_to_local(target, hw))
		_:
			result = _compute_preview_holes(target, preview, 0)
	
	return result


func _compute_preview_results(points: PackedVector2Array) -> Array[PackedVector2Array]:
	var all_results: Array[PackedVector2Array] = []
	for target: LDObjectPolygon in _targets:
		if not is_instance_valid(target):
			continue
		var cut_case: CutCase = _classify_cut(target, points)
		match cut_case:
			CutCase.OUTSIDE:
				continue
			CutCase.SLICE:
				var target_world: PackedVector2Array = _polygon_to_world(target)
				var clipped: Array = Geometry2D.clip_polygons(target_world, points)
				if clipped.is_empty():
					all_results.append(PackedVector2Array())
				else:
					for piece: Variant in clipped:
						if piece is PackedVector2Array and (piece as PackedVector2Array).size() >= 3:
							all_results.append(TerrainPolygon.clean_polygon(piece))
			CutCase.HOLE, CutCase.BRIDGE, CutCase.EXPAND_HOLE:
				all_results.append(_polygon_to_world(target))
			CutCase.REMOVE_HOLE:
				var holes_world: Array[PackedVector2Array] = _holes_to_world(target)
				var target_world: PackedVector2Array = _polygon_to_world(target)
				var combined_cut: PackedVector2Array = points
				for i: int in holes_world.size():
					var hole_intersection: Array = Geometry2D.intersect_polygons(holes_world[i], points)
					if not hole_intersection.is_empty():
						var merged: Array = Geometry2D.merge_polygons(holes_world[i], combined_cut)
						if not merged.is_empty():
							combined_cut = TerrainPolygon.clean_polygon(merged[0])
				var clipped: Array = Geometry2D.clip_polygons(target_world, combined_cut)
				if clipped.is_empty():
					all_results.append(PackedVector2Array())
				else:
					for piece: Variant in clipped:
						if piece is PackedVector2Array and (piece as PackedVector2Array).size() >= 3:
							all_results.append(TerrainPolygon.clean_polygon(piece))
	return all_results


func _get_results_for_target(results: Array[PackedVector2Array], start_idx: int, target_world: PackedVector2Array) -> Array[PackedVector2Array]:
	var preview: PackedVector2Array = _points.duplicate()
	if _cursor_pos != Vector2.ZERO and (preview.is_empty() or preview[preview.size() - 1] != _cursor_pos):
		preview.append(_cursor_pos)
	
	var pieces: Array[PackedVector2Array] = []
	var cut_case: CutCase = CutCase.OUTSIDE
	
	for target: LDObjectPolygon in _targets:
		if not is_instance_valid(target):
			continue
		if _polygon_to_world(target) == target_world:
			cut_case = _classify_cut(target, preview)
			break
	
	match cut_case:
		CutCase.OUTSIDE:
			return pieces
		CutCase.SLICE:
			var clipped: Array = Geometry2D.clip_polygons(target_world, preview)
			for piece: Variant in clipped:
				if piece is PackedVector2Array and (piece as PackedVector2Array).size() >= 3:
					pieces.append(TerrainPolygon.clean_polygon(piece))
		CutCase.HOLE, CutCase.BRIDGE, CutCase.EXPAND_HOLE:
			pieces.append(target_world)
		CutCase.REMOVE_HOLE:
			var combined_cut: PackedVector2Array = preview
			for target: LDObjectPolygon in _targets:
				if not is_instance_valid(target):
					continue
				if _polygon_to_world(target) != target_world:
					continue
				var holes_world: Array[PackedVector2Array] = _holes_to_world(target)
				for i: int in holes_world.size():
					var hole_intersection: Array = Geometry2D.intersect_polygons(holes_world[i], preview)
					if not hole_intersection.is_empty():
						var merged: Array = Geometry2D.merge_polygons(holes_world[i], combined_cut)
						if not merged.is_empty():
							combined_cut = TerrainPolygon.clean_polygon(merged[0])
			var clipped: Array = Geometry2D.clip_polygons(target_world, combined_cut)
			for piece: Variant in clipped:
				if piece is PackedVector2Array and (piece as PackedVector2Array).size() >= 3:
					pieces.append(TerrainPolygon.clean_polygon(piece))
	
	return pieces


func _compute_preview_holes(target: LDObjectPolygon, preview: PackedVector2Array, piece_index: int) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var cut_case: CutCase = _classify_cut(target, preview)
	
	match cut_case:
		CutCase.OUTSIDE:
			for hole: PackedVector2Array in target.get_holes():
				result.append(hole)
		
		CutCase.SLICE:
			for hole: PackedVector2Array in target.get_holes():
				var hole_world: PackedVector2Array = _local_to_world(target, hole)
				var hole_in_cut: Array = Geometry2D.intersect_polygons(hole_world, preview)
				if hole_in_cut.is_empty():
					result.append(hole)
					continue
				var hole_remaining: Array = Geometry2D.clip_polygons(hole_world, preview)
				for piece: Variant in hole_remaining:
					if piece is PackedVector2Array and (piece as PackedVector2Array).size() >= 3:
						var cleaned: PackedVector2Array = TerrainPolygon.clean_polygon(piece)
						if cleaned.size() >= 3:
							result.append(_world_to_local(target, cleaned))
		
		CutCase.HOLE:
			for hole: PackedVector2Array in target.get_holes():
				result.append(hole)
			result.append(_world_to_local(target, preview))
		
		CutCase.BRIDGE:
			var holes_world: Array[PackedVector2Array] = _holes_to_world(target)
			var merged_hole: PackedVector2Array = preview
			for i: int in holes_world.size():
				var hole_intersection: Array = Geometry2D.intersect_polygons(holes_world[i], preview)
				if not hole_intersection.is_empty():
					var merged: Array = Geometry2D.merge_polygons(merged_hole, holes_world[i])
					if not merged.is_empty():
						merged_hole = TerrainPolygon.clean_polygon(merged[0])
				else:
					result.append(target.get_holes()[i])
			var cleaned_merged: PackedVector2Array = TerrainPolygon.clean_polygon(merged_hole)
			if cleaned_merged.size() >= 3:
				result.append(_world_to_local(target, cleaned_merged))
		
		CutCase.REMOVE_HOLE:
			var holes_world: Array[PackedVector2Array] = _holes_to_world(target)
			var combined_cut: PackedVector2Array = preview
			for i: int in holes_world.size():
				var hole_intersection: Array = Geometry2D.intersect_polygons(holes_world[i], preview)
				if hole_intersection.is_empty():
					result.append(target.get_holes()[i])
					continue
				var merged: Array = Geometry2D.merge_polygons(holes_world[i], combined_cut)
				if not merged.is_empty():
					combined_cut = TerrainPolygon.clean_polygon(merged[0])
		
		CutCase.EXPAND_HOLE:
			for i: int in target.get_holes().size():
				var hole_world: PackedVector2Array = _local_to_world(target, target.get_holes()[i])
				var hole_intersection: Array = Geometry2D.intersect_polygons(hole_world, preview)
				if hole_intersection.is_empty():
					result.append(target.get_holes()[i])
				else:
					result.append(_world_to_local(target, preview))
	
	return result


func _commit() -> void:
	if _points.size() < 3:
		return
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Polygon Cut")
	
	for target: LDObjectPolygon in _targets:
		if not is_instance_valid(target):
			continue
		
		var cut_case: CutCase = _classify_cut(target, _points)
		if cut_case == CutCase.OUTSIDE:
			continue
		
		var old_pts: PackedVector2Array = target.get_outer_points().duplicate()
		var old_holes: Array[PackedVector2Array] = target.get_holes().duplicate()
		var old_meta: Dictionary = LDCurveUtil.snapshot_meta(target)
		var obj: LDObjectPolygon = target
		var parent: Node = target.get_parent()
		
		match cut_case:
			CutCase.HOLE:
				var new_holes: Array[PackedVector2Array] = old_holes.duplicate()
				new_holes.append(_world_to_local(target, _points))
				history.add_do(func() -> void:
					if is_instance_valid(obj):
						obj.modulate.a = 1.0
						obj.clear_holes()
						obj.apply_points_raw(old_pts, new_holes)
						LDCurveUtil.invalidate_curve_meta(obj)
				)
				history.add_undo(func() -> void:
					if is_instance_valid(obj):
						obj.modulate.a = 1.0
						obj.clear_holes()
						obj.apply_points_raw(old_pts, old_holes)
						LDCurveUtil.restore_meta(obj, old_meta)
				)
				obj.clear_holes()
				obj.apply_points_raw(old_pts, new_holes)
				LDCurveUtil.invalidate_curve_meta(obj)
			
			CutCase.BRIDGE:
				var holes_world: Array[PackedVector2Array] = _holes_to_world(target)
				var merged_hole: PackedVector2Array = _points
				var new_holes: Array[PackedVector2Array] = []
				for i: int in holes_world.size():
					var hole_intersection: Array = Geometry2D.intersect_polygons(holes_world[i], _points)
					if not hole_intersection.is_empty():
						var merged: Array = Geometry2D.merge_polygons(merged_hole, holes_world[i])
						if not merged.is_empty():
							merged_hole = TerrainPolygon.clean_polygon(merged[0])
					else:
						new_holes.append(old_holes[i])
				var cleaned_merged: PackedVector2Array = TerrainPolygon.clean_polygon(merged_hole)
				if cleaned_merged.size() >= 3:
					new_holes.append(_world_to_local(target, cleaned_merged))
				history.add_do(func() -> void:
					if is_instance_valid(obj):
						obj.modulate.a = 1.0
						obj.clear_holes()
						obj.apply_points_raw(old_pts, new_holes)
						LDCurveUtil.invalidate_curve_meta(obj)
				)
				history.add_undo(func() -> void:
					if is_instance_valid(obj):
						obj.modulate.a = 1.0
						obj.clear_holes()
						obj.apply_points_raw(old_pts, old_holes)
						LDCurveUtil.restore_meta(obj, old_meta)
				)
				obj.clear_holes()
				obj.apply_points_raw(old_pts, new_holes)
				LDCurveUtil.invalidate_curve_meta(obj)
			
			CutCase.EXPAND_HOLE:
				var new_holes: Array[PackedVector2Array] = []
				for i: int in old_holes.size():
					var hole_world: PackedVector2Array = _local_to_world(target, old_holes[i])
					var hole_intersection: Array = Geometry2D.intersect_polygons(hole_world, _points)
					if hole_intersection.is_empty():
						new_holes.append(old_holes[i])
					else:
						new_holes.append(_world_to_local(target, _points))
				history.add_do(func() -> void:
					if is_instance_valid(obj):
						obj.modulate.a = 1.0
						obj.clear_holes()
						obj.apply_points_raw(old_pts, new_holes)
						LDCurveUtil.invalidate_curve_meta(obj)
				)
				history.add_undo(func() -> void:
					if is_instance_valid(obj):
						obj.modulate.a = 1.0
						obj.clear_holes()
						obj.apply_points_raw(old_pts, old_holes)
						LDCurveUtil.restore_meta(obj, old_meta)
				)
				obj.clear_holes()
				obj.apply_points_raw(old_pts, new_holes)
				LDCurveUtil.invalidate_curve_meta(obj)
			
			CutCase.REMOVE_HOLE:
				var holes_world: Array[PackedVector2Array] = _holes_to_world(target)
				var target_world: PackedVector2Array = _polygon_to_world(target)
				var surviving_holes_world: Array[PackedVector2Array] = []
				var surviving_old_holes: Array[PackedVector2Array] = []
				var combined_cut: PackedVector2Array = _points
				
				for i: int in holes_world.size():
					var hole_intersection: Array = Geometry2D.intersect_polygons(holes_world[i], _points)
					if hole_intersection.is_empty():
						surviving_holes_world.append(holes_world[i])
						surviving_old_holes.append(old_holes[i])
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
							obj.clear_holes()
							obj.apply_points_raw(old_pts, old_holes)
							LDCurveUtil.restore_meta(obj, old_meta)
					)
					target.get_parent().remove_child(target)
					continue
				
				var piece_holes: Array[Array] = []
				for ci: int in clipped.size():
					var piece_world: PackedVector2Array = clipped[ci]
					var holes_for_piece: Array[PackedVector2Array] = []
					for hw: PackedVector2Array in surviving_holes_world:
						if Geometry2D.is_point_in_polygon(hw[0], piece_world):
							holes_for_piece.append(_world_to_local(target, hw))
					piece_holes.append(holes_for_piece)
				
				var new_outer: PackedVector2Array = _world_to_local(target, TerrainPolygon.clean_polygon(clipped[0]))
				var first_holes: Array[PackedVector2Array] = piece_holes[0]
				history.add_do(func() -> void:
					if is_instance_valid(obj):
						obj.modulate.a = 1.0
						obj.clear_holes()
						obj.apply_points_raw(new_outer, first_holes)
						LDCurveUtil.invalidate_curve_meta(obj)
				)
				history.add_undo(func() -> void:
					if is_instance_valid(obj):
						obj.modulate.a = 1.0
						obj.clear_holes()
						obj.apply_points_raw(old_pts, old_holes)
						LDCurveUtil.restore_meta(obj, old_meta)
				)
				obj.clear_holes()
				obj.apply_points_raw(new_outer, first_holes)
				LDCurveUtil.invalidate_curve_meta(obj)
				
				var game_object: GameObject = GameObjectDB.get_db().find_game_object(target.source_object_id)
				var layer_id: String = "a0r0"
				if target.get_parent() is LDLayer:
					layer_id = (target.get_parent() as LDLayer).layer_id
				
				for ci: int in range(1, clipped.size()):
					var piece: PackedVector2Array = clipped[ci]
					if piece.size() < 3:
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
					var piece_local: PackedVector2Array = PackedVector2Array()
					for p: Vector2 in piece_cleaned:
						piece_local.append(p - centroid)
					var adjusted_holes: Array[PackedVector2Array] = []
					for hw: PackedVector2Array in (piece_holes[ci] as Array[PackedVector2Array]):
						var adjusted: PackedVector2Array = PackedVector2Array()
						for p: Vector2 in hw:
							adjusted.append(p - centroid)
						adjusted_holes.append(adjusted)
					viewport.add_object(new_poly, Vector2i(centroid), layer_id)
					new_poly.init_properties(game_object)
					new_poly.apply_points_raw(piece_local, adjusted_holes)
					LDCurveUtil.invalidate_curve_meta(new_poly)
					new_poly.place()
					history.add_do(func() -> void:
						if is_instance_valid(new_poly) and not new_poly.is_inside_tree():
							parent.add_child(new_poly)
							LDCurveUtil.invalidate_curve_meta(new_poly)
					)
					history.add_undo(func() -> void:
						if is_instance_valid(new_poly) and new_poly.is_inside_tree():
							new_poly.get_parent().remove_child(new_poly)
					)
			
			CutCase.SLICE:
				var target_world: PackedVector2Array = _polygon_to_world(target)
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
							obj.clear_holes()
							obj.apply_points_raw(old_pts, old_holes)
							LDCurveUtil.restore_meta(obj, old_meta)
					)
					target.get_parent().remove_child(target)
					continue
				
				var piece_holes: Array[Array] = []
				for ci: int in clipped.size():
					var piece_world: PackedVector2Array = clipped[ci]
					var holes_for_piece: Array[PackedVector2Array] = []
					for hole: PackedVector2Array in old_holes:
						var hole_world: PackedVector2Array = _local_to_world(target, hole)
						var hole_in_cut: Array = Geometry2D.intersect_polygons(hole_world, _points)
						if not hole_in_cut.is_empty():
							var hole_remaining: Array = Geometry2D.clip_polygons(hole_world, _points)
							for piece: Variant in hole_remaining:
								if not piece is PackedVector2Array or (piece as PackedVector2Array).size() < 3:
									continue
								var cleaned: PackedVector2Array = TerrainPolygon.clean_polygon(piece)
								if cleaned.size() < 3:
									continue
								if Geometry2D.is_point_in_polygon(cleaned[0], piece_world):
									holes_for_piece.append(_world_to_local(target, cleaned))
						else:
							if Geometry2D.is_point_in_polygon(hole_world[0], piece_world):
								holes_for_piece.append(hole)
					piece_holes.append(holes_for_piece)
				
				var first_local: PackedVector2Array = _world_to_local(target, TerrainPolygon.clean_polygon(clipped[0]))
				var first_holes: Array[PackedVector2Array] = piece_holes[0]
				
				history.add_do(func() -> void:
					if is_instance_valid(obj):
						obj.modulate.a = 1.0
						obj.clear_holes()
						obj.apply_points_raw(first_local, first_holes)
						LDCurveUtil.invalidate_curve_meta(obj)
				)
				history.add_undo(func() -> void:
					if is_instance_valid(obj):
						obj.modulate.a = 1.0
						obj.clear_holes()
						obj.apply_points_raw(old_pts, old_holes)
						LDCurveUtil.restore_meta(obj, old_meta)
				)
				obj.clear_holes()
				obj.apply_points_raw(first_local, first_holes)
				LDCurveUtil.invalidate_curve_meta(obj)
				
				var game_object: GameObject = GameObjectDB.get_db().find_game_object(target.source_object_id)
				var layer_id: String = "a0r0"
				if target.get_parent() is LDLayer:
					layer_id = (target.get_parent() as LDLayer).layer_id
				
				var valid_piece_idx: int = 1
				for ci: int in range(1, clipped.size()):
					var piece: Variant = clipped[ci]
					if not piece is PackedVector2Array or (piece as PackedVector2Array).size() < 3:
						continue
					if not game_object or not game_object.ld_editor_instance:
						continue
					var new_instance: LDObject = game_object.ld_editor_instance.instantiate() as LDObject
					if not new_instance is LDObjectPolygon:
						new_instance.queue_free()
						valid_piece_idx += 1
						continue
					var new_poly: LDObjectPolygon = new_instance as LDObjectPolygon
					var piece_cleaned: PackedVector2Array = TerrainPolygon.clean_polygon(piece)
					var centroid: Vector2 = Vector2.ZERO
					for p: Vector2 in piece_cleaned:
						centroid += p
					centroid = (centroid / piece_cleaned.size()).snapped(Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE))
					var piece_local: PackedVector2Array = PackedVector2Array()
					for p: Vector2 in piece_cleaned:
						piece_local.append(p - centroid)
					var holes_for_this_piece: Array[PackedVector2Array] = piece_holes[valid_piece_idx] if valid_piece_idx < piece_holes.size() else []
					var adjusted_holes: Array[PackedVector2Array] = []
					for h: PackedVector2Array in holes_for_this_piece:
						var adjusted: PackedVector2Array = PackedVector2Array()
						for p: Vector2 in h:
							var world_p: Vector2 = target.get_global_transform() * p
							adjusted.append(world_p - centroid)
						adjusted_holes.append(adjusted)
					viewport.add_object(new_poly, Vector2i(centroid), layer_id)
					new_poly.init_properties(game_object)
					new_poly.apply_points_raw(piece_local, adjusted_holes)
					LDCurveUtil.invalidate_curve_meta(new_poly)
					new_poly.place()
					history.add_do(func() -> void:
						if is_instance_valid(new_poly) and not new_poly.is_inside_tree():
							parent.add_child(new_poly)
							LDCurveUtil.invalidate_curve_meta(new_poly)
					)
					history.add_undo(func() -> void:
						if is_instance_valid(new_poly) and new_poly.is_inside_tree():
							new_poly.get_parent().remove_child(new_poly)
					)
					valid_piece_idx += 1
	
	history.commit_action()
	_points = PackedVector2Array()
	get_tool_handler().select_tool("select")


func _is_cut_fully_inside(target: PackedVector2Array, cut: PackedVector2Array) -> bool:
	for p: Vector2 in cut:
		if not Geometry2D.is_point_in_polygon(p, target):
			return false
	return true


func _on_bake_overlay_draw() -> void:
	if not is_active():
		return
	var preview: PackedVector2Array = _points.duplicate()
	if _cursor_pos != Vector2.ZERO and (preview.is_empty() or preview[preview.size() - 1] != _cursor_pos):
		preview.append(_cursor_pos)
	if preview.size() < 3:
		return
	for target: LDObjectPolygon in _targets:
		if not is_instance_valid(target):
			continue
		var cut_case: CutCase = _classify_cut(target, preview)
		if cut_case == CutCase.OUTSIDE or cut_case == CutCase.HOLE or cut_case == CutCase.BRIDGE:
			continue
		var old_meta: Dictionary = LDCurveUtil.snapshot_meta(target)
		if old_meta.is_empty():
			continue
		var xform: Transform2D = target.get_global_transform()
		var xform_inv: Transform2D = xform.affine_inverse()
		var cut_local: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in preview:
			cut_local.append(xform_inv * p)
		var ctrl_outer_raw: Variant = old_meta.get("ctrl_outer")
		if ctrl_outer_raw == null:
			continue
		var ctrl_outer: PackedVector2Array = PackedVector2Array(ctrl_outer_raw)
		var affected: PackedInt32Array = LDCurveUtil.get_affected_outer_segments(ctrl_outer, old_meta, cut_local)
		if affected.is_empty():
			continue
		var canvas: Transform2D = viewport.get_viewport().get_canvas_transform()
		var root_xform: Transform2D = viewport.get_root().get_global_transform()
		var to_screen: Transform2D = canvas * root_xform
		for seg_idx: int in affected:
			var ni: int = (seg_idx + 1) % ctrl_outer.size()
			var key_curr: String = "hk_o:" + str(seg_idx)
			var key_next: String = "hk_o:" + str(ni)
			var h_curr_arr: Variant = old_meta.get(key_curr)
			var h_next_arr: Variant = old_meta.get(key_next)
			var p0: Vector2 = ctrl_outer[seg_idx]
			var p3: Vector2 = ctrl_outer[ni]
			var h_out: Vector2 = Vector2.ZERO
			var h_in: Vector2 = Vector2.ZERO
			if h_curr_arr != null:
				var arr: Array = h_curr_arr as Array
				if arr.size() == 4:
					h_out = Vector2(float(arr[2]), float(arr[3]))
			if h_next_arr != null:
				var arr: Array = h_next_arr as Array
				if arr.size() == 4:
					h_in = Vector2(float(arr[0]), float(arr[1]))
			var p1: Vector2 = p0 + h_out
			var p2: Vector2 = p3 + h_in
			var prev_pt: Vector2 = to_screen * (xform * p0)
			for s: int in range(1, 13):
				var t: float = float(s) / 12.0
				var curr_pt: Vector2 = to_screen * (xform * LDCurveUtil.cubic_bezier(p0, p1, p2, p3, t))
				_overlay.draw_line(prev_pt, curr_pt, Color(1.0, 0.5, 0.0, 1.0), 2.5)
				prev_pt = curr_pt
