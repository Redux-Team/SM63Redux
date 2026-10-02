extends Control

@export var unit_tests: UnitTester
@export var test: Gradient


func _ready() -> void:
	if OS.has_feature("debug"):
		print_rich("\n[color=yellow]Debug mode [color=green]ON\n")
		
		if unit_tests:
			print("Running unit tests...")
			unit_tests._run_tests(false)
	
	print_rich("\nProfiling... ([color=red]-1.0[/color] to [color=green]1.0[/color])")
	await Profile.run()
	print()
