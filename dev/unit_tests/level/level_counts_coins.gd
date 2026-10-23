static func run_test() -> void:
	var level: Level = (load("res://game/level/level.tscn") as PackedScene).instantiate()
	var changes: Array[Array] = []
	var shines: Array[int] = []
	var kickouts: Array[bool] = []
	level.coins_changed.connect(
			func(kind: StringName, count: int, total: int) -> void:
				changes.append([kind, count, total])
	)
	level.shine_collected.connect(func(scenario: int) -> void: shines.append(scenario))
	level.kickout_requested.connect(func() -> void: kickouts.append(true))
	
	assert(level.get_coin_counter(&"red") == Vector2i.ZERO)
	level.register_coin(&"red")
	level.register_coin(&"red")
	level.register_coin(&"red", &"secret")
	level.register_coin(&"purple")
	assert(level.get_coin_counter(&"red") == Vector2i(0, 2))
	assert(level.get_coin_counter(&"red", &"secret") == Vector2i(0, 1))
	assert(level.get_coin_counter(&"purple") == Vector2i(0, 1))
	assert(changes.back() == [&"purple", 0, 1])
	assert(changes[2] == [&"red", 0, 3])
	
	assert(level.collect_coin(&"red") == 1)
	assert(changes.back() == [&"red", 1, 3])
	assert(level.collect_coin(&"red", 2, &"secret") == 2)
	assert(changes.back() == [&"red", 3, 3])
	assert(level.get_coin_counter(&"red", &"secret") == Vector2i(2, 1))
	assert(level.collect_coin(&"yellow", 5) == 5)
	assert(level.get_coin_counter(&"yellow") == Vector2i(5, 0))
	assert(changes.back() == [&"yellow", 5, 0])
	assert(changes.size() == 7)
	
	level.collect_shine(3)
	level.request_kickout()
	assert(shines == ([3] as Array[int]))
	assert(kickouts.size() == 1)
	
	assert(level.get_time() == 0.0)
	level._physics_process(0.5)
	level._physics_process(0.25)
	assert(level.get_time() == 0.75)
	
	var child: Node2D = Node2D.new()
	var grandchild: Node2D = Node2D.new()
	level.add_child(child)
	child.add_child(grandchild)
	assert(Level.of(grandchild) == level)
	assert(Level.of(level) == level)
	var orphan: Node = Node.new()
	assert(Level.of(orphan) == null)
	orphan.free()
	assert(level.get_player() == null)
	assert(level.get_area() == null)
	level.free()
