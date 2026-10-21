static func run_test() -> void:
	var dir: String = "user://unit_test_level_file"
	DirAccess.make_dir_recursive_absolute(dir)
	var level: LevelData = LevelData.create()
	level.level_name = "File Test"
	var dict: Dictionary = level.to_dict()
	
	var json_path: String = dir.path_join("level.json")
	var binary_path: String = dir.path_join("level.63rl")
	assert(LevelFile.write(json_path, level) == OK)
	assert(LevelFile.write(binary_path, level) == OK)
	assert(not LevelFile.is_legacy(json_path))
	assert(not LevelFile.is_legacy(binary_path))
	
	var header: PackedByteArray = FileAccess.get_file_as_bytes(binary_path).slice(0, LevelFile.COMPRESSED_MAGIC.size())
	assert(header == LevelFile.COMPRESSED_MAGIC)
	assert(FileAccess.get_file_as_string(json_path).begins_with("{"))
	
	var raw_path: String = dir.path_join("raw.63rl")
	var raw: FileAccess = FileAccess.open(raw_path, FileAccess.WRITE)
	raw.store_buffer(var_to_bytes(dict))
	raw.close()
	assert(LevelFile.read(raw_path).to_dict() == dict)
	
	var other_extension: String = dir.path_join("level.bin")
	assert(LevelFile.write(other_extension, level) == OK)
	assert(LevelFile.read(other_extension).to_dict() == dict)
	
	var legacy_path: String = dir.path_join("legacy.json")
	var legacy: FileAccess = FileAccess.open(legacy_path, FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"version": 1, "areas": [{"name": "Old", "layers": [{"layer_index": 0, "objects": [{"object_id": "yellow_coin", "position": [16, 32]}]}]}]}))
	legacy.close()
	assert(LevelFile.is_legacy(legacy_path))
	var converted: LevelData = LevelFile.read(legacy_path)
	assert(converted.version == LevelData.VERSION)
	assert((converted.areas.front() as AreaData).area_name == "Old")
	var coin: ObjectData = ((converted.areas.front() as AreaData).layers.front() as LayerData).objects.front()
	assert(coin.id == &"yellow_coin")
	assert(coin.position == Vector2(16.0, 32.0))
	
	var garbage_path: String = dir.path_join("garbage.json")
	var garbage: FileAccess = FileAccess.open(garbage_path, FileAccess.WRITE)
	garbage.store_string("\"just a string\"")
	garbage.close()
	UnitTester.expect_error("type prefix is not recognized")
	UnitTester.expect_error("could not read")
	assert(LevelFile.read(garbage_path) == null)
	UnitTester.expect_error("type prefix is not recognized")
	assert(not LevelFile.is_legacy(garbage_path))
	
	var invalid_path: String = dir.path_join("invalid.json")
	var invalid: FileAccess = FileAccess.open(invalid_path, FileAccess.WRITE)
	invalid.store_string("{not json")
	invalid.close()
	UnitTester.expect_error("Parse JSON failed")
	UnitTester.expect_error("could not read")
	assert(LevelFile.read(invalid_path) == null)
	
	var empty_path: String = dir.path_join("empty.json")
	FileAccess.open(empty_path, FileAccess.WRITE).close()
	UnitTester.expect_error("could not read")
	assert(LevelFile.read(empty_path) == null)
	
	UnitTester.expect_error("could not read")
	assert(LevelFile.read(dir.path_join("missing.63rl")) == null)
	assert(not LevelFile.is_legacy(dir.path_join("missing.63rl")))
	
	assert(LevelFile.write(dir.path_join("missing_dir/level.json"), level) != OK)
	assert(LevelFile.write(dir.path_join("missing_dir/level.63rl"), level) != OK)
	
	for file: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)
