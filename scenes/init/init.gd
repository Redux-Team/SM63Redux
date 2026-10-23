extends Control

@export var unit_tests: UnitTester
@export var debug_overlay: PackedScene


func _ready() -> void:
	(
			Singleton.build_screen_transition()
			.set_fade()
			.set_out_duration(0.0)
			.set_loading_delay(0.0)
			.load(_profile)
			.add_threaded_task(_scan_objects)
			.set_destination("uid://dp3ocrpop234v")
			.done()
	)


func _run_debug_tools() -> void:
	if not OS.has_feature("debug"):
		return
	
	print_rich("\n[color=yellow]Debug mode [color=green]ON\n")
	if unit_tests:
		print("Running unit tests...")
		unit_tests._run_tests(false)
	
	if debug_overlay:
		Singleton.add_child.call_deferred(debug_overlay.instantiate())


func _scan_objects() -> void:
	ObjectRegistry.scan()
	_run_debug_tools()


func _profile() -> void:
	print_rich("\nProfiling... ([color=red]-1.0[/color] to " + "[color=green]1.0[/color])")
	await Profile.run()
	print()
