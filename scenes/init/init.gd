extends Control

@export var unit_tests: UnitTester


func _ready() -> void:
	if OS.has_feature("debug"):
		print_rich("[color=yellow]Debug mode [color=green]ON")
		
		if unit_tests:
			print("Running unit tests...")
			unit_tests._run_tests(false)
