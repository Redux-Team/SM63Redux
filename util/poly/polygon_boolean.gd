@abstract class_name PolygonBoolean


static func split(polygons: Array[PackedVector2Array]) -> Array[Array]:
	var shapes: Array[Array] = []
	var holes: Array[PackedVector2Array] = []
	for polygon: PackedVector2Array in polygons:
		if polygon.size() < PolygonShape.MIN_POINTS:
			continue
		
		if Geometry2D.is_polygon_clockwise(polygon):
			holes.append(polygon)
		else:
			shapes.append([polygon])
	
	for hole: PackedVector2Array in holes:
		for shape: Array in shapes:
			if Geometry2D.is_point_in_polygon(inner_point(hole), shape.front()):
				add_hole(shape, hole)
				break
	
	return shapes


static func subtract(shape: Array, cutter: PackedVector2Array) -> Array[Array]:
	var pieces: Array[Array] = split(Geometry2D.clip_polygons(shape.front(), cutter))
	for hole: PackedVector2Array in shape.slice(1):
		var carved: Array[Array] = []
		for piece: Array in pieces:
			carved.append_array(_carve(piece, hole))
		pieces = carved
	
	return pieces


static func union(shapes: Array[Array], stroke: PackedVector2Array) -> Array:
	var outer: PackedVector2Array = stroke
	var holes: Array[PackedVector2Array] = []
	var absorbed: Array[Array] = []
	var pending: Array[Array] = shapes.duplicate()
	var merged: bool = true
	while merged:
		merged = false
		for shape: Array in pending:
			if Geometry2D.intersect_polygons(outer, shape.front()).is_empty():
				continue
			
			var result: Array[Array] = split(Geometry2D.merge_polygons(outer, shape.front()))
			if result.size() != 1:
				continue
			
			outer = result.front().front()
			var remaining: Array[PackedVector2Array] = []
			for hole: PackedVector2Array in holes:
				remaining.append_array(_outside(hole, shape.front()))
			holes = remaining
			holes.append_array(result.front().slice(1))
			absorbed.append(shape)
			pending.erase(shape)
			merged = true
			break
	
	var solids: Array[PackedVector2Array] = [stroke]
	for shape: Array in absorbed:
		solids.append(shape.front())
	for shape: Array in absorbed:
		for hole: PackedVector2Array in shape.slice(1):
			var pieces: Array[PackedVector2Array] = [hole]
			for solid: PackedVector2Array in solids:
				if solid == shape.front():
					continue
				
				var clipped: Array[PackedVector2Array] = []
				for piece: PackedVector2Array in pieces:
					clipped.append_array(_outside(piece, solid))
				pieces = clipped
			holes.append_array(pieces)
	
	var result_shape: Array = [outer]
	for hole: PackedVector2Array in holes:
		add_hole(result_shape, hole)
	
	return [result_shape, absorbed]


static func add_hole(shape: Array, hole: PackedVector2Array) -> void:
	var merged: PackedVector2Array = hole
	var index: int = 1
	while index < shape.size():
		var existing: PackedVector2Array = shape.get(index)
		if Geometry2D.intersect_polygons(merged, existing).is_empty():
			index += 1
			continue
		
		var combined: Array[PackedVector2Array] = Geometry2D.merge_polygons(merged, existing)
		merged = combined.filter(func(polygon: PackedVector2Array) -> bool: return not Geometry2D.is_polygon_clockwise(polygon)).front()
		shape.remove_at(index)
		index = 1
	
	shape.append(merged)


static func inner_point(polygon: PackedVector2Array) -> Vector2:
	var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
	if triangles.size() < 3:
		return polygon.get(0)
	
	return (polygon.get(triangles.get(0)) + polygon.get(triangles.get(1)) + polygon.get(triangles.get(2))) / 3.0


static func _outside(polygon: PackedVector2Array, cutter: PackedVector2Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for shape: Array in split(Geometry2D.clip_polygons(polygon, cutter)):
		result.append(shape.front())
	
	return result


static func _carve(shape: Array, hole: PackedVector2Array) -> Array[Array]:
	var pieces: Array[Array] = split(Geometry2D.clip_polygons(shape.front(), hole))
	for existing: PackedVector2Array in shape.slice(1):
		for piece: Array in pieces:
			if Geometry2D.is_point_in_polygon(inner_point(existing), piece.front()):
				add_hole(piece, existing)
				break
	
	return pieces
