static func run_test() -> void:
	var block_data: ObjectData = ObjectData.create(&"spinning_block")
	block_data.shape = { "size": Vector2(96, 64) }
	var block: GameObject = ObjectRegistry.spawn(block_data, GameObject.Context.EDITOR)
	var block_shape: BlockShape = block.shape as BlockShape
	assert(block_shape.get_kind() == ObjectShape.Kind.BLOCK)
	assert(block_shape.size == Vector2(96, 64).clamp(block_shape.min_size, block_shape.max_size))
	assert(block.to_data().shape == { "size": block_shape.size })
	var visual: Vector2 = block_shape.size + Vector2.ONE * block_shape.padding
	assert(block_shape.get_local_bounds() == Rect2(-visual * 0.5, visual))
	assert(block_shape.contains_point(Vector2.ZERO))
	assert(not block_shape.contains_point(visual))
	assert(block_shape.get_outlines().size() == 1)
	var changes: Array[bool] = []
	block_shape.changed.connect(func() -> void: changes.append(true))
	block_shape.set_size(Vector2(100000, -5))
	assert(
			block_shape.size
			== block_shape.max_size * Vector2(1, 0)
			+ block_shape.min_size * Vector2(0, 1)
	)
	assert(changes.size() == 1)
	for rect: Control in block_shape.rects:
		assert(rect.size == block_shape.size + Vector2.ONE * block_shape.padding)
		assert(rect.position == -rect.size * 0.5)
	block_shape.from_data({})
	assert(
			block_shape.size
			== block_shape.default_size.clamp(block_shape.min_size, block_shape.max_size)
	)
	block.free()
	
	var path_data: ObjectData = ObjectData.create(&"tall_mushroom")
	var points: PackedVector2Array = \
			PackedVector2Array([Vector2(0, 0), Vector2(0, -64), Vector2(32, -96)])
	path_data.shape = { "points": points }
	var path: GameObject = ObjectRegistry.spawn(path_data, GameObject.Context.EDITOR)
	var path_shape: PathShape = path.shape as PathShape
	assert(path_shape.get_kind() == ObjectShape.Kind.PATH)
	assert(path_shape.get_points() == points)
	assert(path.to_data().shape == { "points": points })
	assert(is_equal_approx(path_shape.get_head_rotation(), -PI))
	assert(path_shape.contains_point(Vector2(0, -32)))
	assert(path_shape.contains_point(Vector2(16, -80)))
	assert(not path_shape.contains_point(Vector2(200, -32)))
	var bounds: Rect2 = path_shape.get_local_bounds()
	for point: Vector2 in points:
		assert(bounds.has_point(point))
	var segments: int = points.size() - 1
	assert(path_shape.get_outlines().size() == segments + (1 if path_shape.head else 0))
	var resolved: PackedVector2Array = path_shape.get_resolved_points()
	assert(resolved.size() >= points.size())
	assert(resolved[0] == points[0])
	assert(resolved[resolved.size() - 1] == points[points.size() - 1])
	path_shape.set_points(PackedVector2Array([Vector2.ONE]))
	assert(path_shape.get_points() == path_shape.default_points)
	path_shape.from_data({})
	assert(path_shape.get_points() == path_shape.default_points)
	var copy: PackedVector2Array = path_shape.get_points()
	copy[0] = Vector2(999, 999)
	assert(path_shape.get_points()[0] != Vector2(999, 999))
	path.free()
	
	var platform_data: ObjectData = ObjectData.create(&"wooden_platform")
	platform_data.shape = { "units": 4 }
	var platform: GameObject = ObjectRegistry.spawn(platform_data, GameObject.Context.EDITOR)
	var telescoping: TelescopingShape = platform.shape as TelescopingShape
	assert(telescoping.get_kind() == ObjectShape.Kind.TELESCOPING)
	assert(telescoping.units == 4)
	assert(platform.to_data().shape == { "units": 4 })
	assert(
			telescoping.get_length()
			== telescoping.get_caps_length()
			+ telescoping.get_segment_length() * 4
	)
	assert(telescoping.get_length(0) == telescoping.get_caps_length())
	assert(telescoping.get_length(-3) == telescoping.get_caps_length())
	assert(telescoping.get_segment_length() > 0.0)
	telescoping.set_units(telescoping.max_units + 10)
	assert(telescoping.units == telescoping.max_units)
	telescoping.set_units(-10)
	assert(telescoping.units == telescoping.min_units)
	telescoping.from_data({})
	assert(
			telescoping.units
			== clampi(telescoping.default_units, telescoping.min_units, telescoping.max_units)
	)
	telescoping.set_units(6)
	if telescoping.patch:
		var axis_length: float = (
				telescoping.patch.size.x
				if telescoping.axis == TelescopingShape.Axis.HORIZONTAL
				else telescoping.patch.size.y
		)
		assert(is_equal_approx(axis_length, telescoping.get_length()))
		assert(telescoping.patch.position == -telescoping.patch.size * 0.5)
		assert(
				telescoping.get_local_bounds()
				== Rect2(telescoping.patch.position, telescoping.patch.size)
		)
	assert(
			telescoping.get_axis_vector()
			== (
					Vector2.RIGHT
					if telescoping.axis == TelescopingShape.Axis.HORIZONTAL
					else Vector2.DOWN
			)
	)
	platform.free()
	
	var plain: GameObject = \
			ObjectRegistry.spawn(ObjectData.create(&"goomba"), GameObject.Context.EDITOR)
	assert(plain.shape == null)
	assert(plain.to_data().shape.is_empty())
	assert(plain.get_outlines().size() == 1)
	plain.free()
