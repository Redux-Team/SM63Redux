const SCENES: PackedStringArray = [
	"res://scenes/title_screen/title_screen.tscn",
	"res://scenes/level_designer/level_designer.tscn",
	"res://scenes/settings_screen/settings_screen.tscn",
]
const FRAMES: int = 10


static func run_test() -> void:
	var tree: SceneTree = Engine.get_main_loop()
	for path: String in SCENES:
		var scene: Node = (load(path) as PackedScene).instantiate()
		tree.root.add_child(scene)
		for i: int in FRAMES:
			await tree.physics_frame
		
		assert(scene.is_inside_tree())
		scene.free()
		await tree.process_frame
