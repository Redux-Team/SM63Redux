static func run_test() -> void:
	var tree: SceneTree = Engine.get_main_loop()
	var root: Node2D = Node2D.new()
	tree.root.add_child(root)
	
	var big: Node = Node.new()
	for i: int in Teardown.UNIT_SIZE + 4:
		big.add_child(Node.new())
	var small: Node = Node.new()
	small.add_child(Node.new())
	root.add_child(small)
	root.add_child(big)
	root.add_child(Node.new())
	
	var units: Array[Node] = []
	Teardown._collect_units(root, units)
	assert(units.size() == 3 + Teardown.UNIT_SIZE + 4)
	assert(units.back() == small)
	assert(units.find(big) == Teardown.UNIT_SIZE + 5)
	
	await Teardown.free_descendants(root)
	assert(root.get_child_count() == 0)
	assert(not is_instance_valid(big))
	assert(not is_instance_valid(small))
	
	var loose: Array = [Node.new(), null, Node.new()]
	var first: Node = loose.front()
	await Teardown.free_nodes(loose, tree)
	assert(not is_instance_valid(first))
	
	var world: Node2D = Node2D.new()
	world.position = Vector2(100.0, 50.0)
	root.add_child(world)
	var object: GameObject = GameObject.new()
	object.position = Vector2(10.0, 0.0)
	world.add_child(object)
	var behind_marker: Node2D = Node2D.new()
	world.add_child(behind_marker)
	var source: Node2D = Node2D.new()
	source.position = Vector2(5.0, 5.0)
	object.add_child(source)
	
	var spawned: Node2D = Node2D.new()
	Spawner.spawn_near(source, spawned, Vector2(1.0, 2.0))
	assert(spawned.get_parent() == null)
	await tree.process_frame
	assert(spawned.get_parent() == world)
	assert(spawned.global_position.is_equal_approx(Vector2(116.0, 57.0)))
	
	var behind: Node2D = Node2D.new()
	Spawner.spawn_near(source, behind, Vector2.ZERO, true)
	await tree.process_frame
	assert(behind.get_parent() == world)
	assert(behind.get_index() < object.get_index())
	
	var orphan_source: Node2D = Node2D.new()
	var orphan_parent: Node2D = Node2D.new()
	orphan_parent.add_child(orphan_source)
	var discarded: Node2D = Node2D.new()
	Spawner.spawn_near(orphan_source, discarded)
	assert(not is_instance_valid(discarded))
	orphan_parent.free()
	
	var burst_scene: PackedScene = PackedScene.new()
	var template: Node2D = Node2D.new()
	burst_scene.pack(template)
	template.free()
	var before: int = world.get_child_count()
	Spawner.spawn_burst(source, burst_scene, 5, 8.0)
	await tree.process_frame
	assert(world.get_child_count() == before + 5)
	for child: Node in world.get_children().slice(before):
		var offset: Vector2 = (child as Node2D).global_position - source.global_position
		assert(absf(offset.x) <= 8.0 and is_zero_approx(offset.y))
	
	root.free()
