const Files: GDScript = preload("res://dev/unit_tests/project/_files.gd")


static func run_test() -> void:
	var paths: PackedStringArray = Files.find(["gd"])
	assert(paths.size() > 100)
	
	for path: String in paths:
		var script: GDScript = load(path)
		if script == null:
			UnitTester.fail(path, 0, "Script failed to load")
		elif not script.can_instantiate() and not script.is_abstract():
			UnitTester.fail(path, 0, "Script failed to compile")
