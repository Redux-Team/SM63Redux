static func run_test() -> void:
	var history: LDHistoryHandler = LDHistoryHandler.new()
	history.max_steps = 3
	history.setup(null)
	var target: Node2D = Node2D.new()
	var changes: Array[int] = []
	history.changed.connect(func() -> void: changes.append(history.get_version()))
	
	var start: int = history.get_version()
	var action: LDHistoryHandler.Action = history.create("Move")
	assert(action.do(target.set_position.bind(Vector2(1, 0))) == action)
	assert(action.undo(target.set_position.bind(Vector2.ZERO)) == action)
	var owned_by_undo: Node = Node.new()
	assert(action.keep_on_undo(owned_by_undo) == action)
	action.commit()
	assert(target.position == Vector2(1, 0))
	assert(history.get_version() == start + 1)
	assert(not changes.is_empty())
	
	history.undo()
	assert(target.position == Vector2.ZERO)
	assert(history.get_version() == start)
	history.redo()
	assert(target.position == Vector2(1, 0))
	history.redo()
	assert(target.position == Vector2(1, 0))
	
	for step: int in range(2, 7):
		_move(history, target, Vector2(step, 0))
	assert(target.position == Vector2(6, 0))
	assert(not is_instance_valid(owned_by_undo))
	for i: int in 10:
		history.undo()
	assert(target.position == Vector2(3, 0))
	for i: int in 10:
		history.redo()
	assert(target.position == Vector2(6, 0))
	
	var owned_by_do: Node = Node.new()
	history.create("Spawn").do(target.set_position.bind(Vector2(7, 0))).undo(target.set_position.bind(Vector2(6, 0))).keep_on_do(owned_by_do).commit()
	history.undo()
	assert(is_instance_valid(owned_by_do))
	history.undo()
	_move(history, target, Vector2(42, 0))
	assert(not is_instance_valid(owned_by_do))
	history.redo()
	assert(target.position == Vector2(42, 0))
	history.undo()
	assert(target.position == Vector2(5, 0))
	history.redo()
	
	for x: int in [10, 20, 30]:
		history.create("Drag", UndoRedo.MERGE_ENDS).do(target.set_position.bind(Vector2(x, 0))).undo(target.set_position.bind(Vector2(42, 0))).commit()
	assert(target.position == Vector2(30, 0))
	history.undo()
	assert(target.position == Vector2(42, 0))
	history.redo()
	assert(target.position == Vector2(30, 0))
	
	var before_clear: int = changes.size()
	history.clear()
	assert(changes.size() > before_clear)
	history.undo()
	assert(target.position == Vector2(30, 0))
	
	history.free()
	target.free()


static func _move(history: LDHistoryHandler, target: Node2D, to: Vector2) -> void:
	history.create("Move").do(target.set_position.bind(to)).undo(target.set_position.bind(target.position)).commit()
