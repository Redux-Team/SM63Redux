extends Control

@export var unit_tests: UnitTester


func _ready() -> void:
	if OS.has_feature("debug") and unit_tests:
		print("Running unit tests...")
		unit_tests._run_tests(false)
