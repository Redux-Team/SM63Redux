static func run_test() -> void:
	var events: Array[String] = []
	var machine: StateMachine = StateMachine.new()
	machine.manual_tick = true
	var ground: Probe = Probe.create(&"Ground", events, machine)
	var idle: Probe = Probe.create(&"Idle", events, ground)
	var walk: Probe = Probe.create(&"WalkFast", events, ground)
	var air: Probe = Probe.create(&"Air", events, machine)
	var fall: Probe = Probe.create(&"Fall", events, air)
	machine.initial_state = idle
	var changes: Array[StringName] = []
	machine.state_changed.connect(func(_from: State, to: State) -> void: changes.append(to.name))
	_get_tree().root.add_child(machine)
	
	assert(events == ["bind Ground", "bind Idle", "bind WalkFast", "bind Air", "bind Fall", "enter Ground", "enter Idle"])
	assert(machine.get_state() == idle)
	assert(machine.get_state_name() == &"Idle")
	assert(idle.is_current())
	assert(not ground.is_current())
	assert(ground.is_active())
	assert(machine.is_active(&"Ground"))
	assert(not machine.is_active(&"Air"))
	assert(machine.get_active_states() == [ground, idle])
	assert(idle.machine == machine and idle.entity == null and idle.sprite == null)
	events.clear()
	
	idle.next_state = &"WalkFast"
	machine.tick(0.25)
	assert(events == ["tick Ground", "tick Idle", "exit Idle", "enter WalkFast"])
	assert(machine.get_state() == walk)
	assert(machine.get_last_state() == idle)
	assert(walk.frames == 0)
	machine.tick(0.25)
	assert(ground.frames == 2)
	assert(is_equal_approx(ground.time, 0.5))
	assert(walk.frames == 1)
	events.clear()
	
	machine.change_state(&"fall")
	assert(events == ["exit WalkFast", "exit Ground", "enter Air", "enter Fall"])
	assert(machine.get_state() == fall)
	events.clear()
	
	machine.change_state(&"walk_fast")
	assert(machine.get_state() == walk)
	machine.change_state(&"Fall")
	events.clear()
	
	air.next_state = &"Idle"
	machine.tick(0.1)
	assert(machine.get_state() == idle)
	assert(events == ["tick Air", "tick Fall", "exit Fall", "exit Air", "enter Ground", "enter Idle"])
	air.next_state = &""
	idle.next_state = &""
	events.clear()
	
	idle.change_on_tick = &"Fall"
	machine.tick(0.1)
	assert(machine.get_state() == fall)
	assert(events == ["tick Ground", "tick Idle", "exit Idle", "exit Ground", "enter Air", "enter Fall"])
	idle.change_on_tick = &""
	
	assert(machine.get_history() == [&"Idle", &"WalkFast", &"Fall", &"WalkFast", &"Fall", &"Idle", &"Fall"])
	assert(changes == machine.get_history())
	
	events.clear()
	machine.restore_state(&"WalkFast")
	assert(machine.get_state() == walk)
	assert(machine.get_last_state() == fall)
	assert(machine.get_active_states() == [ground, walk])
	assert(events.is_empty())
	machine.restore_state(&"Missing")
	assert(machine.get_state() == walk)
	
	UnitTester.expect_error("no state named 'Swim'")
	machine.change_state(&"Swim")
	assert(machine.get_state() == walk)
	
	UnitTester.expect_error("requested unknown state 'Nowhere'")
	walk.next_state = &"Nowhere"
	machine.tick(0.1)
	assert(machine.get_state() == walk)
	walk.next_state = &""
	
	for i: int in StateMachine.HISTORY_SIZE + 4:
		machine.change_state(&"Idle" if i % 2 == 0 else &"Fall")
	assert(machine.get_history().size() == StateMachine.HISTORY_SIZE)
	assert(machine.get_history().back() == machine.get_state_name())
	
	machine.change_state(&"Idle")
	events.clear()
	machine.stop()
	assert(events == ["exit Idle", "exit Ground"])
	assert(machine.get_state() == null)
	assert(machine.get_state_name() == &"")
	machine.tick(0.1)
	assert(events == ["exit Idle", "exit Ground"])
	machine.stop()
	machine.free()
	
	var duplicated: StateMachine = StateMachine.new()
	duplicated.manual_tick = true
	Probe.create(&"Twin", events, Probe.create(&"Left", events, duplicated))
	Probe.create(&"Twin", events, Probe.create(&"Right", events, duplicated))
	UnitTester.expect_error("duplicate state name 'Twin'")
	UnitTester.expect_error("duplicate state name 'twin'")
	_get_tree().root.add_child(duplicated)
	duplicated.free()


static func _get_tree() -> SceneTree:
	return Engine.get_main_loop()


class Probe extends State:
	var events: Array[String]
	var next_state: StringName = &""
	var change_on_tick: StringName = &""
	
	
	static func create(state_name: StringName, into: Array[String], parent: Node) -> Probe:
		var probe: Probe = Probe.new()
		probe.name = state_name
		probe.events = into
		parent.add_child(probe, true)
		return probe
	
	
	func _bind() -> void:
		events.append("bind %s" % name)
	
	
	func _enter() -> void:
		events.append("enter %s" % name)
	
	
	func _exit() -> void:
		events.append("exit %s" % name)
	
	
	func _tick(_delta: float) -> void:
		events.append("tick %s" % name)
		if not change_on_tick.is_empty():
			machine.change_state(change_on_tick)
	
	
	func _next() -> StringName:
		return next_state
