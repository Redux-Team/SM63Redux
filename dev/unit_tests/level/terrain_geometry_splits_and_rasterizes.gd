static func run_test() -> void:
	var square: PackedVector2Array = \
			PackedVector2Array([Vector2(0, 0), Vector2(64, 0), Vector2(64, 64), Vector2(0, 64)])
	var reversed: PackedVector2Array = TerrainPolygon.reverse_points(square)
	assert(
			reversed
			== PackedVector2Array([Vector2(0, 64), Vector2(64, 64), Vector2(64, 0), Vector2(0, 0)])
	)
	assert(square[0] == Vector2(0, 0))
	assert(TerrainPolygon.signed_area(square) == -8192.0)
	assert(TerrainPolygon.signed_area(reversed) == 8192.0)
	assert(TerrainPolygon.is_clockwise(square))
	assert(not TerrainPolygon.is_clockwise(reversed))
	assert(TerrainPolygon.ensure_clockwise(reversed) == square)
	assert(TerrainPolygon.ensure_clockwise(square) == square)
	assert(TerrainPolygon.ensure_counter_clockwise(square) == reversed)
	assert(TerrainPolygon.edge_normal(Vector2.ZERO, Vector2(10, 0)) == Vector2(0, -1))
	assert(TerrainPolygon.edge_normal(Vector2.ZERO, Vector2(0, 10)) == Vector2(1, 0))
	assert(TerrainPolygon.get_bounds(square) == Rect2(0, 0, 64, 64))
	assert(TerrainPolygon.get_bounds(PackedVector2Array()) == Rect2())
	assert(
			TerrainPolygon.get_bounds(PackedVector2Array([Vector2(-5, 3), Vector2(7, -9)]))
			== Rect2(-5, -9, 12, 12)
	)
	
	var noisy: PackedVector2Array = PackedVector2Array(
			[Vector2(0, 0), Vector2(0.1, 0), Vector2(64, 0), Vector2(64, 64), Vector2(0, 64)]
	)
	assert(
			TerrainPolygon.clean_polygon(noisy)
			== PackedVector2Array([Vector2(0, 0), Vector2(64, 0), Vector2(64, 64), Vector2(0, 64)])
	)
	assert(
			TerrainPolygon.clean_polygon(
					PackedVector2Array([Vector2.ZERO, Vector2.ONE])
			).size() == 2
	)
	assert(TerrainPolygon.get_closed_points(square).size() == 5)
	assert(TerrainPolygon.get_closed_points(square)[4] == square[0])
	assert(TerrainPolygon.get_closed_points(PackedVector2Array()).is_empty())
	
	var hole: PackedVector2Array = \
			PackedVector2Array([Vector2(16, 16), Vector2(48, 16), Vector2(48, 48), Vector2(16, 48)])
	var outside: PackedVector2Array = \
			PackedVector2Array([Vector2(200, 200), Vector2(232, 200), Vector2(232, 232)])
	assert(
			TerrainPolygon.split_into_pieces(square, [] as Array[PackedVector2Array])
			== ([square] as Array[PackedVector2Array])
	)
	assert(
			TerrainPolygon.split_into_pieces(
					PackedVector2Array([Vector2.ZERO, Vector2.ONE]),
					[] as Array[PackedVector2Array],
			).is_empty()
	)
	assert(
			TerrainPolygon.split_into_pieces(
					square,
					[outside] as Array[PackedVector2Array],
			).size() == 1
	)
	var pieces: Array[PackedVector2Array] = \
			TerrainPolygon.split_into_pieces(square, [hole, outside] as Array[PackedVector2Array])
	assert(pieces.size() >= 2)
	var area: float = 0.0
	for piece: PackedVector2Array in pieces:
		area += absf(TerrainPolygon.signed_area(piece)) * 0.5
		assert(not Geometry2D.is_point_in_polygon(Vector2(32, 32), piece))
	assert(is_equal_approx(area, 4096.0 - 1024.0))
	assert(
			pieces.any(
					func(piece: PackedVector2Array) -> bool: return (
							Geometry2D.is_point_in_polygon(Vector2(8, 32), piece)
					)
			)
	)
	assert(
			pieces.any(
					func(piece: PackedVector2Array) -> bool: return (
							Geometry2D.is_point_in_polygon(Vector2(56, 32), piece)
					)
			)
	)
	
	assert(TerrainPolygon.is_top_edge(Vector2(0, 0), Vector2(64, 0), 0.5, false))
	assert(not TerrainPolygon.is_top_edge(Vector2(0, 0), Vector2(64, 0), 0.5, true))
	assert(TerrainPolygon.is_top_edge(Vector2(0, 0), Vector2(64, -32), 0.5, false))
	assert(not TerrainPolygon.is_top_edge(Vector2(0, 0), Vector2(64, -128), 0.5, false))
	assert(
			TerrainPolygon.get_topline_flags(square, true, 0.5, {})
			== ([true, false, false, false] as Array[bool])
	)
	assert(
			TerrainPolygon.get_topline_flags(reversed, true, 0.5, {})
			== ([false, false, true, false] as Array[bool])
	)
	assert(
			TerrainPolygon.get_topline_flags(square, true, 0.5, { 0: false, 1: true })
			== ([false, true, false, false] as Array[bool])
	)
	assert(
			TerrainPolygon.get_topline_flags(square, true, 0.5, {}, false)
			== ([false, false, false, false] as Array[bool])
	)
	
	var single: Array[PackedVector2Array] = TerrainPolygon.get_topline_segments(
			square,
			[true, false, false, false] as Array[bool],
			true,
	)
	assert(
			single
			== ([PackedVector2Array([Vector2(0, 0), Vector2(64, 0)])] as Array[PackedVector2Array])
	)
	var joined: Array[PackedVector2Array] = TerrainPolygon.get_topline_segments(
			square,
			[true, false, false, true] as Array[bool],
			true,
	)
	assert(
			joined
			== (
					[PackedVector2Array([Vector2(0, 64), Vector2(0, 0), Vector2(64, 0)])]
					as Array[PackedVector2Array]
			)
	)
	assert(
			TerrainPolygon.get_topline_segments(
					square,
					[true, false, true, false] as Array[bool],
					true,
			).size() == 2
	)
	assert(
			TerrainPolygon.get_topline_segments(
					square,
					[false, false, false, false] as Array[bool],
					true,
			).is_empty()
	)
	var flipped: Array[PackedVector2Array] = (
			TerrainPolygon.get_topline_segments(
					reversed,
					[false, false, true, false] as Array[bool],
					true,
			)
	)
	assert(
			flipped
			== ([PackedVector2Array([Vector2(0, 0), Vector2(64, 0)])] as Array[PackedVector2Array])
	)
	
	var line: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(100, 0)])
	var texture: GradientTexture1D = GradientTexture1D.new()
	texture.width = 32
	var subdivided: PackedVector2Array = TerrainPolygon.subdivide_for_line2d(line, texture)
	assert(subdivided.size() == 5)
	assert(subdivided[1] == Vector2(25, 0))
	assert(subdivided[4] == Vector2(100, 0))
	assert(TerrainPolygon.subdivide_for_line2d(line, null) == line)
	assert(
			TerrainPolygon.offset_polyline(line, 4.0)
			== PackedVector2Array([Vector2(0, -4), Vector2(100, -4)])
	)
	assert(TerrainPolygon.offset_polyline(line, 0.0) == line)
	var corner: PackedVector2Array = TerrainPolygon.offset_polyline(
			PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10)]),
			1.0,
	)
	assert(corner[1].is_equal_approx(Vector2(10, 0) + Vector2(1, -1).normalized()))
	assert(
			TerrainPolygon.inset_polyline(line, 10.0, 20.0)
			== PackedVector2Array([Vector2(10, 0), Vector2(80, 0)])
	)
	assert(TerrainPolygon.inset_polyline(PackedVector2Array([Vector2.ONE]), 1.0, 1.0).size() == 1)
	
	assert(TileGrid.cell_offset == Vector2(16, 16))
	assert(TileGrid.world_to_cell(Vector2(16, 16)) == Vector2i(0, 0))
	assert(TileGrid.world_to_cell(Vector2(47, 47)) == Vector2i(0, 0))
	assert(TileGrid.world_to_cell(Vector2(15, 48)) == Vector2i(-1, 1))
	assert(TileGrid.cell_to_world(Vector2i(2, -1)) == Vector2(80, -16))
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(-3, 7), Vector2i(12, -4)]:
		assert(TileGrid.world_to_cell(TileGrid.cell_to_world(cell)) == cell)
	var aligned: PackedVector2Array = \
			PackedVector2Array([Vector2(16, 16), Vector2(80, 16), Vector2(80, 80), Vector2(16, 80)])
	assert(TileGrid.is_aligned(aligned))
	assert(TileGrid.is_aligned(PackedVector2Array([Vector2(16.4, -15.6)])))
	assert(not TileGrid.is_aligned(square))
	
	var cells: Dictionary[Vector2i, bool] = \
			TileGrid.rasterize(aligned, [] as Array[PackedVector2Array])
	assert(cells.size() == 4)
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		assert(cells.has(cell))
	assert(
			TileGrid.rasterize(
					PackedVector2Array([Vector2.ZERO, Vector2.ONE]),
					[] as Array[PackedVector2Array],
			).is_empty()
	)
	assert(TileGrid.point_bounds(aligned) == Rect2i(0, 0, 2, 2))
	assert(TileGrid.cell_bounds(cells) == Rect2i(0, 0, 2, 2))
	assert(TileGrid.cell_bounds({} as Dictionary[Vector2i, bool]) == Rect2i())
	
	var shapes: Array[TileGrid.Shape] = TileGrid.trace(cells)
	assert(shapes.size() == 1)
	assert(shapes.front().holes.is_empty())
	assert(shapes.front().outer.size() == 4)
	assert(TerrainPolygon.get_bounds(shapes.front().outer) == Rect2(16, 16, 64, 64))
	assert(TileGrid.rasterize(shapes.front().outer, shapes.front().holes) == cells)
	
	var ring: Dictionary[Vector2i, bool] = {}
	for y: int in 3:
		for x: int in 3:
			if x != 1 or y != 1:
				ring[Vector2i(x, y)] = true
	var ring_shapes: Array[TileGrid.Shape] = TileGrid.trace(ring)
	assert(ring_shapes.size() == 1)
	assert(ring_shapes.front().holes.size() == 1)
	assert(ring_shapes.front().get_rings().size() == 2)
	assert(TerrainPolygon.get_bounds(ring_shapes.front().holes.front()) == Rect2(48, 48, 32, 32))
	assert(TileGrid.rasterize(ring_shapes.front().outer, ring_shapes.front().holes) == ring)
	assert(TileGrid.enclosed(ring) == ({ Vector2i(1, 1): true } as Dictionary[Vector2i, bool]))
	assert(
			TileGrid.region(ring, Vector2i(1, 1))
			== ({ Vector2i(1, 1): true } as Dictionary[Vector2i, bool])
	)
	assert(TileGrid.region(ring, Vector2i(5, 5)).is_empty())
	assert(TileGrid.enclosed({} as Dictionary[Vector2i, bool]).is_empty())
	
	var separate: Dictionary[Vector2i, bool] = {
		Vector2i(0, 0): true,
		Vector2i(5, 0): true,
	}
	assert(TileGrid.trace(separate).size() == 2)
	var diagonal: Dictionary[Vector2i, bool] = {
		Vector2i(0, 0): true,
		Vector2i(1, 1): true,
	}
	var pinched: Array[TileGrid.Shape] = TileGrid.trace(diagonal)
	assert(pinched.size() == 1)
	var pinch: PackedVector2Array = pinched.front().outer
	assert(pinch.size() == 8)
	assert(not pinch.has(Vector2(48, 48)))
	assert(
			Array(pinch).filter(
					func(point: Vector2) -> bool: return (
							point.distance_to(Vector2(48, 48))
							<= TileGrid.PINCH_EPSILON + 0.001
					)
			).size() == 2
	)
	
	var dilated: Dictionary[Vector2i, bool] = \
			TileGrid.dilate({ Vector2i(0, 0): true } as Dictionary[Vector2i, bool])
	assert(dilated.size() == 5)
	assert(
			dilated.has(Vector2i(0, -1))
			and dilated.has(Vector2i(-1, 0))
			and dilated.has(Vector2i(1, 0))
			and dilated.has(Vector2i(0, 1))
	)
	assert(
			TileGrid.line(Vector2i(0, 0), Vector2i(3, 0))
			== ([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)] as Array[Vector2i])
	)
	assert(TileGrid.line(Vector2i(2, 2), Vector2i(2, 2)) == ([Vector2i(2, 2)] as Array[Vector2i]))
	assert(TileGrid.line(Vector2i(0, 0), Vector2i(2, 4)).size() == 5)
