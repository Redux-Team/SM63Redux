extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var filter: String = _get_option(args, "--filter")
	var results: Array[UnitTester.Result] = await UnitTester.run_all(args.has("--verbose"), filter)
	if OS.get_environment("GITHUB_ACTIONS") == "true":
		_annotate(results)
		_write_summary(results, OS.get_environment("GITHUB_STEP_SUMMARY"))
	
	quit(1 if results.is_empty() or UnitTester.count_failed(results) > 0 else 0)


func _get_option(args: PackedStringArray, option: String) -> String:
	var at: int = args.find(option)
	return args.get(at + 1) if at >= 0 and at + 1 < args.size() else ""


func _annotate(results: Array[UnitTester.Result]) -> void:
	for result: UnitTester.Result in results:
		for failure: UnitTester.Failure in result.failures:
			var file: String = failure.file.trim_prefix("res://") if failure.file.begins_with("res://") else result.path.trim_prefix("res://")
			print("::error file=%s,line=%d,title=%s::%s" % [file, maxi(failure.line, 1), result.get_name(), failure.message.replace("\n", "%0A")])


func _write_summary(results: Array[UnitTester.Result], path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE) if not path.is_empty() else null
	if file == null:
		return
	
	var failed: int = UnitTester.count_failed(results)
	var lines: PackedStringArray = [
		"## Unit tests",
		"",
		"%s **%d** of **%d** test files passed" % ["X" if failed > 0 else "W", results.size() - failed, results.size()],
		"",
		"| Result | Test | Time |",
		"| :-: | --- | --: |",
	]
	for result: UnitTester.Result in results:
		var icon: String = "X" if result.is_failed() else "S" if result.is_skipped() else "W"
		lines.append("| %s | `%s` | %.2fs |" % [icon, result.get_name(), result.seconds])
		for failure: UnitTester.Failure in result.failures:
			lines.append("| | -> %s | |" % str(failure).replace("|", "\\|"))
	
	file.seek_end()
	file.store_string("\n".join(lines) + "\n")
