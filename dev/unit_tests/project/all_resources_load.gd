const Files: GDScript = preload("res://dev/unit_tests/project/_files.gd")
const SKIPPED: PackedStringArray = ["res://assets/textures/level_designer/tool_widgets"]


static func run_test() -> void:
	for path: String in Files.find(["tres", "gdshader"]):
		if SKIPPED.has(path.get_base_dir()):
			continue
		
		if load(path) == null:
			UnitTester.fail(path, 0, "Resource failed to load")
	
	for path: String in Files.find(["tscn"]):
		var scene: PackedScene = load(path)
		if scene == null:
			UnitTester.fail(path, 0, "Scene failed to load")
			continue
		
		var instance: Node = scene.instantiate()
		if instance == null:
			UnitTester.fail(path, 0, "Scene failed to instantiate")
			continue
		
		instance.free()
