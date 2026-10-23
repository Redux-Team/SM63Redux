@tool
static func run_test() -> void:
	var base: Dictionary = {
		"a": 1,
		"nested": { "x": 1, "y": 2 },
		"list": [1, 2],
	}
	var merged: Dictionary = \
			Packer.merge_deep(base, { "b": 2, "nested": { "y": 3, "z": 4 }, "list": [3] })
	assert(
			merged
			== {
				"a": 1,
				"b": 2,
				"nested": { "x": 1, "y": 3, "z": 4 },
				"list": [3],
			}
	)
	assert(base == { "a": 1, "nested": { "x": 1, "y": 2 }, "list": [1, 2] })
	assert(Packer.merge_deep({ "nested": { "x": 1 } }, { "nested": 5 }) == { "nested": 5 })
	assert(Packer.merge_deep({}, {}) == {})
	
	var uuid_pattern: RegEx = RegEx.create_from_string(
			"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-"
			+ "[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
	)
	var uuids: Dictionary[String, bool] = {}
	for i: int in 64:
		var uuid: String = Packer.generate_uuid()
		assert(uuid_pattern.search(uuid) != null)
		uuids[uuid] = true
	assert(uuids.size() == 64)
	
	assert(Packer.array_to_vec2([3, -4.5]) == Vector2(3.0, -4.5))
	assert(Packer.array_to_vec2([1]) == Vector2.ZERO)
	assert(Packer.array_to_vec2("1, 2") == Vector2.ZERO)
	assert(
			Packer.array_to_packed_vec2([[1, 2], [3, 4]])
			== PackedVector2Array([Vector2(1.0, 2.0), Vector2(3.0, 4.0)])
	)
	assert(Packer.array_to_packed_vec2([]).is_empty())
	
	var points: PackedVector2Array = PackedVector2Array([Vector2(1.0, 2.0), Vector2(-3.5, 4.25)])
	assert(Packer.to_packed_vec2(points) == points)
	assert(Packer.to_packed_vec2([[1, 2], [-3.5, 4.25]]) == points)
	assert(Packer.to_packed_vec2("[(1, 2), (-3.5,4.25)]") == points)
	assert(Packer.to_packed_vec2("[(1), (2, 3)]") == PackedVector2Array([Vector2(2.0, 3.0)]))
	assert(Packer.to_packed_vec2("no points").is_empty())
	assert(Packer.to_packed_vec2(42).is_empty())
	
	assert(Packer.array_to_color([1, 0.5, 0, 0.25]) == Color(1.0, 0.5, 0.0, 0.25))
	assert(Packer.array_to_color([1, 0.5, 0]) == Color.WHITE)
	assert(Packer.color_to_array(Color(0.25, 0.5, 0.75, 1.0)) == [0.25, 0.5, 0.75, 1.0])
	assert(Packer.vec2_to_array(Vector2(7.0, -8.0)) == [7.0, -8.0])
	
	for value: Variant in [Vector2(1.5, -2.0), Color(0.1, 0.2, 0.3, 0.4)]:
		assert(Packer.deserialize_json_variant(Packer.serialize_json_variant(value)) == value)
	assert(Packer.serialize_json_variant(Vector2i(3, 4)) == [3, 4])
	assert(Packer.serialize_json_variant("text") == "text")
	assert(Packer.deserialize_json_variant([1, 2, 3]) == [1, 2, 3])
	assert(Packer.deserialize_json_variant(5) == 5)
	
	assert(Packer.get_texture_as_shape(null) == null)
	var texture: PlaceholderTexture2D = PlaceholderTexture2D.new()
	texture.size = Vector2(24.0, 40.0)
	var shape: RectangleShape2D = Packer.get_texture_as_shape(texture)
	assert(shape.size == Vector2(24.0, 40.0))
	assert(shape.resource_local_to_scene)
