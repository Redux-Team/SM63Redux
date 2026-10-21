@tool
static func run_test() -> void:
	var level: LevelData = LevelData.create()
	var area: AreaData = level.areas.front()
	var layer: LayerData = area.layers.front()
	var block: ObjectData = ObjectData.create(&"big_rock")
	block.position = Vector2(12.5, 64.0)
	block.values.set(&"amount", 3)
	block.shape = {"outer": PackedVector2Array([Vector2.ZERO, Vector2(32.0, 0.0), Vector2(32.0, 32.0)])}
	layer.objects.append(block)
	layer.objects.append(ObjectData.create(&"player_mario"))
	area.layers.append(LayerData.create(1))
	var dict: Dictionary = level.to_dict()
	
	assert(LevelData.from_dict(dict).to_dict() == dict)
	assert(JSON.to_native(JSON.parse_string(JSON.stringify(JSON.from_native(dict)))) == dict)
	
	for extension: String in [LevelFile.EXTENSION_JSON, LevelFile.EXTENSION_BINARY]:
		var path: String = "user://unit_test_level.%s" % extension
		assert(LevelFile.write(path, level) == OK)
		assert(LevelFile.read(path).to_dict() == dict)
		DirAccess.remove_absolute(path)
	
	UnitTester.expect_error("unsupported level version")
	assert(LevelData.from_dict({"version": 1}) == null)
	
	block.values.clear()
	block.shape.clear()
	var built: LevelArea = LevelArea.build(area, GameObject.Context.EDITOR)
	assert(built.get_layers().size() == 2)
	assert(built.get_all_objects().size() == 2)
	assert(built.find_object(block.uuid).position == block.position)
	assert(built.capture().to_dict() == area.to_dict())
	built.free()
