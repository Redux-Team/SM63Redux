@tool
@warning_ignore_start("unused_private_class_variable")
class_name UnitTester
extends Resource


@export_tool_button("Run tests", "Debug") var _run_unit_tests: Callable:
	get:
		return _run_tests.bind(false)
@export_tool_button("Run tests (Verbose)", "Debug") var _run_unit_tests_verbose: Callable:
	get:
		return _run_tests.bind(true)


func _run_tests(verbose: bool) -> void:
	var dir: String = resource_path.get_base_dir()
	for test_file: String in DirAccess.get_files_at(dir):
		if test_file.ends_with(".gd") and not test_file.begins_with("_"):
			FileAccess.open(test_file, FileAccess.READ)
			var script: GDScript = load(dir.path_join(test_file))
			if script.has_script_method(&"run_test"):
				if verbose:
					print("Running %s" % test_file)
				script.call(&"run_test")
			else:
				print_rich("[color=yellow]Skipping %s (no \"run_test\" method found)" % test_file)
	print_rich("[color=green]Successfully ran all unit tests!")
