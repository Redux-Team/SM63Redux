static func run_test() -> void:
	var outer: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(64, 0), Vector2(64, 64), Vector2(0, 64)])
	var hole: PackedVector2Array = PackedVector2Array([Vector2(16, 16), Vector2(48, 16), Vector2(48, 48), Vector2(16, 48)])
	var data: ObjectData = ObjectData.create(&"terrain_grass")
	data.shape = {"outer": outer, "holes": [hole, PackedVector2Array([Vector2.ZERO, Vector2.ONE])], "toplines": [Vector3i(0, 2, 1), Vector3i(1, 0, 0), Vector3i(5, 0, 1)]}
	var object: GameObject = ObjectRegistry.spawn(data, GameObject.Context.EDITOR)
	var shape: PolygonShape = object.shape as PolygonShape
	assert(shape != null)
	assert(shape.get_kind() == ObjectShape.Kind.POLYGON)
	assert(shape.outer == outer)
	assert(shape.holes.size() == 1)
	assert(shape.get_rings().size() == 2)
	assert(shape.get_ring_points(1) == hole)
	assert(shape.get_toplines() == ([{2: true}, {0: false}] as Array[Dictionary]))
	
	var saved: Dictionary = object.to_data().shape
	assert(saved.get("outer") == outer)
	assert(saved.get("holes") == [hole])
	assert((saved.get("toplines") as Array).size() == 2)
	assert((saved.get("toplines") as Array).has(Vector3i(0, 2, 1)))
	assert((saved.get("toplines") as Array).has(Vector3i(1, 0, 0)))
	assert(not saved.has("tiled"))
	
	assert(shape.get_local_bounds() == Rect2(0, 0, 64, 64))
	assert(object.get_local_bounds() == Rect2(0, 0, 64, 64))
	assert(shape.contains_point(Vector2(8, 8)))
	assert(not shape.contains_point(Vector2(32, 32)))
	assert(not shape.contains_point(Vector2(100, 8)))
	assert(object.contains_point(Vector2(8, 8)))
	assert(shape.get_outlines().size() == 2)
	
	var area: float = 0.0
	for piece: PackedVector2Array in shape.get_pieces():
		area += absf(TerrainPolygon.signed_area(piece)) * 0.5
		assert(not Geometry2D.is_point_in_polygon(Vector2(32, 32), piece))
	assert(is_equal_approx(area, 64.0 * 64.0 - 32.0 * 32.0))
	assert(shape.get_pieces() == shape.get_pieces())
	
	assert(shape.get_topline_flags(0) == ([true, false, true, false] as Array[bool]))
	assert(shape.get_topline_flags(1) == ([false, false, true, false] as Array[bool]))
	shape.auto_toplines = false
	assert(shape.get_topline_flags(0) == ([false, false, true, false] as Array[bool]))
	assert(shape.get_topline_flags(1) == ([false, false, false, false] as Array[bool]))
	assert(shape.get_topline_segments().size() == 1)
	shape.auto_toplines = true
	assert(shape.is_on_topline(Vector2(32, 0), 1.0))
	assert(shape.is_on_topline(Vector2(32, 64), 1.0))
	assert(not shape.is_on_topline(Vector2(64, 32), 1.0))
	
	shape.set_rings([outer] as Array[PackedVector2Array], [] as Array[Dictionary])
	assert(shape.holes.is_empty())
	assert(shape.get_toplines() == ([{}] as Array[Dictionary]))
	assert(shape.contains_point(Vector2(32, 32)))
	assert(shape.get_pieces().size() == 1)
	object.free()
	
	assert(PolygonShape.insert_override({0: true, 2: false}, 1, 4) == {0: true, 1: true, 3: false})
	assert(PolygonShape.insert_override({3: true}, 0, 4) == {0: true, 4: true})
	assert(PolygonShape.insert_override({}, 2, 4) == {})
	assert(PolygonShape.remove_override({0: true, 1: true, 3: false}, 1, 5) == {0: true, 2: false})
	assert(PolygonShape.remove_override({1: false, 2: true}, 2, 4) == {1: false})
	assert(PolygonShape.remove_override({0: true}, 0, 4) == {2: true})
	
	var aligned: PackedVector2Array = PackedVector2Array([Vector2(16, 16), Vector2(80, 16), Vector2(80, 80), Vector2(16, 80)])
	var tiled_data: ObjectData = ObjectData.create(&"terrain_grass")
	tiled_data.shape = {"outer": aligned, "holes": [], "toplines": [], "tiled": true}
	var tiled: GameObject = ObjectRegistry.spawn(tiled_data, GameObject.Context.EDITOR)
	var tiled_shape: PolygonShape = tiled.shape as PolygonShape
	assert(tiled_shape.is_tiled())
	assert(tiled.to_data().shape.get("tiled") == true)
	tiled.position = Vector2(32, 64)
	assert(tiled_shape.is_tiled())
	tiled.position = Vector2(8, 0)
	assert(not tiled_shape.is_tiled())
	tiled.position = Vector2.ZERO
	tiled.rotation = 0.5
	assert(not tiled_shape.is_tiled())
	tiled.rotation = 0.0
	tiled.scale = Vector2(2, 2)
	assert(not tiled_shape.is_tiled())
	tiled.scale = Vector2.ONE
	tiled_shape.tiled = false
	assert(not tiled_shape.is_tiled())
	assert(not tiled.to_data().shape.has("tiled"))
	tiled.free()
	
	var defaulted: GameObject = ObjectRegistry.spawn(ObjectData.create(&"water"), GameObject.Context.EDITOR)
	assert((defaulted.shape as PolygonShape).outer == (defaulted.shape as PolygonShape).default_outer)
	defaulted.free()
