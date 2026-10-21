static func run_test() -> void:
	var events: Array[String] = []
	var host: Node = Node.new()
	var machine: ModeMachine = ModeMachine.new()
	machine.host = host
	var hover: Probe = Probe.create(&"Hover", events)
	var rocket: Probe = Probe.create(&"Rocket", events)
	machine.add_child(hover)
	machine.add_child(rocket)
	machine.add_child(Node.new())
	_get_tree().root.add_child(machine)
	
	assert(machine.get_modes().size() == 2)
	assert(machine.get_mode(&"Hover") == hover)
	assert(hover.machine == machine)
	assert(hover.host == host)
	assert(events == ["bind Hover", "bind Rocket"])
	events.clear()
	
	var started: Array[Mode] = []
	var stopped: Array[Mode] = []
	machine.mode_started.connect(func(mode: Mode) -> void: started.append(mode))
	machine.mode_stopped.connect(func(mode: Mode) -> void: stopped.append(mode))
	
	machine.tick(0.1)
	assert(machine.get_running() == null)
	
	machine.select(&"Hover")
	assert(machine.get_selected() == hover)
	assert(machine.get_running() == null)
	machine.tick(0.1)
	machine.tick(0.1)
	assert(machine.is_running(&"Hover"))
	assert(hover.is_running())
	assert(not rocket.is_running())
	assert(hover.frames == 2)
	assert(is_equal_approx(hover.time, 0.2))
	assert(events == ["enter Hover", "tick Hover", "tick Hover"])
	assert(started == [hover])
	events.clear()
	
	machine.tick(0.1, false)
	assert(machine.get_running() == null)
	assert(events == ["exit Hover"])
	assert(stopped == [hover])
	machine.tick(0.1)
	assert(hover.frames == 1)
	events.clear()
	
	machine.select(&"Rocket")
	machine.tick(0.1)
	assert(events == ["exit Hover", "enter Rocket", "tick Rocket"])
	events.clear()
	
	rocket.available = false
	machine.tick(0.1)
	assert(machine.get_running() == null)
	assert(events == ["exit Rocket"])
	rocket.available = true
	machine.tick(0.1)
	assert(machine.is_running(&"Rocket"))
	machine.stop()
	assert(machine.get_running() == null)
	machine.stop()
	
	UnitTester.expect_error("no mode named 'Turbo'")
	machine.select(&"Turbo")
	assert(machine.get_selected() == null)
	machine.select(&"")
	machine.free()
	host.free()
	
	_run_multi()


static func _run_multi() -> void:
	var events: Array[String] = []
	var machine: MultiModeMachine = MultiModeMachine.new()
	var metal: Probe = Probe.create(&"Metal", events)
	var wing: Probe = Probe.create(&"Wing", events)
	var locked: Probe = Probe.create(&"Locked", events)
	locked.available = false
	for mode: Mode in [metal, wing, locked]:
		machine.add_child(mode)
	_get_tree().root.add_child(machine)
	events.clear()
	
	assert(machine.get_running() == null)
	machine.start(&"Metal")
	machine.start(&"Wing", true)
	machine.start(&"Metal")
	machine.start(&"Locked")
	assert(machine.get_running_modes() == [metal, wing])
	assert(machine.get_running() == wing)
	assert(wing.permanent)
	assert(not metal.permanent)
	assert(not machine.is_running(&"Locked"))
	assert(events == ["enter Metal", "enter Wing"])
	events.clear()
	
	machine.tick(0.5)
	machine.tick(0.5, false)
	assert(metal.frames == 1 and wing.frames == 1)
	assert(events == ["tick Metal", "tick Wing"])
	events.clear()
	
	metal.end()
	assert(not metal.is_running())
	assert(machine.get_running_modes() == [wing])
	machine.end(&"Metal")
	machine.toggle(&"Wing")
	machine.toggle(&"Metal", true)
	assert(machine.get_running_modes() == [metal])
	assert(metal.permanent)
	assert(events == ["exit Metal", "exit Wing", "enter Metal"])
	events.clear()
	
	metal.ending_on_tick = true
	machine.start(&"Wing")
	machine.tick(0.1)
	assert(machine.get_running_modes() == [wing])
	assert(events == ["enter Wing", "tick Metal", "exit Metal", "tick Wing"])
	
	machine.stop()
	assert(machine.get_running_modes().is_empty())
	
	UnitTester.expect_error("no mode named 'Ghost'")
	machine.start(&"Ghost")
	machine.end(&"Ghost")
	machine.free()


static func _get_tree() -> SceneTree:
	return Engine.get_main_loop()


class Probe extends Mode:
	var events: Array[String]
	var available: bool = true
	var ending_on_tick: bool = false
	
	
	static func create(mode_name: StringName, into: Array[String]) -> Probe:
		var probe: Probe = Probe.new()
		probe.name = mode_name
		probe.events = into
		return probe
	
	
	func _bind() -> void:
		events.append("bind %s" % name)
	
	
	func _is_available() -> bool:
		return available
	
	
	func _enter() -> void:
		events.append("enter %s" % name)
	
	
	func _tick(_delta: float) -> void:
		events.append("tick %s" % name)
		if ending_on_tick:
			end()
	
	
	func _exit() -> void:
		events.append("exit %s" % name)
