static func run_test() -> void:
	var tree: SceneTree = Engine.get_main_loop()
	var root: Node2D = Node2D.new()
	var culler: LevelCuller = LevelCuller.new()
	culler.frames_between_updates = 1
	root.add_child(culler)
	tree.root.add_child(root)
	
	var water_data: ObjectData = ObjectData.create(&"water")
	water_data.shape = {"outer": PackedVector2Array([Vector2(-32, -32), Vector2(32, -32), Vector2(32, 32), Vector2(-32, 32)]), "holes": [], "toplines": []}
	var water: GameObject = ObjectRegistry.spawn(water_data, GameObject.Context.GAME)
	var terrain: GameObject = ObjectRegistry.spawn(ObjectData.create(&"terrain_grass"), GameObject.Context.GAME)
	root.add_child(water)
	root.add_child(terrain)
	var water_areas: Array[Node] = water.find_children("*", "Area2D", true, false)
	var terrain_bodies: Array[Node] = terrain.find_children("*", "StaticBody2D", true, false)
	assert(not water_areas.is_empty())
	assert(not terrain_bodies.is_empty())
	
	culler.track(terrain)
	culler.track(water)
	for body: StaticBody2D in terrain_bodies:
		assert(body.disable_mode != CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE)
	for area: Area2D in water_areas:
		assert(area.disable_mode == CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE)
	
	culler._physics_process(0.0)
	assert(water.process_mode != Node.PROCESS_MODE_DISABLED)
	
	water.position = Vector2(100000.0, 0.0)
	terrain.position = Vector2(100000.0, 0.0)
	culler._physics_process(0.0)
	assert(water.process_mode == Node.PROCESS_MODE_DISABLED)
	assert(terrain.process_mode != Node.PROCESS_MODE_DISABLED)
	for area: Area2D in water_areas:
		assert(not area.monitoring)
	
	water.position = culler.get_viewport().get_visible_rect().end + Vector2.ONE * (culler.margin - 1.0)
	culler._physics_process(0.0)
	assert(water.process_mode == Node.PROCESS_MODE_INHERIT)
	for area: Area2D in water_areas:
		assert(area.monitoring)
	
	culler.frames_between_updates = 3
	water.position = Vector2(100000.0, 0.0)
	culler._physics_process(0.0)
	culler._physics_process(0.0)
	assert(water.process_mode == Node.PROCESS_MODE_INHERIT)
	culler._physics_process(0.0)
	culler._physics_process(0.0)
	culler._physics_process(0.0)
	assert(water.process_mode == Node.PROCESS_MODE_DISABLED)
	
	water.free()
	culler.frames_between_updates = 1
	culler._physics_process(0.0)
	root.free()
