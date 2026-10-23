@tool
@warning_ignore_start("unused_private_class_variable")
class_name UnitTester
extends Resource

const ROOT: String = "res://dev/unit_tests"
const ENTRY: StringName = &"run_test"

static var _capture: Capture

@export_tool_button("Run tests", "Debug") var _run_unit_tests: Callable:
	get:
		return _run_tests.bind(false)
@export_tool_button("Run tests (Verbose)", "Debug")
var _run_unit_tests_verbose: Callable:
	get:
		return _run_tests.bind(true)


static func run_all(verbose: bool, filter: String = "", tool_only: bool = false) -> Array[Result]:
	var results: Array[Result] = []
	_capture = Capture.new()
	OS.add_logger(_capture)
	var filters: PackedStringArray = filter.split(",", false)
	for path: String in find_tests(ROOT):
		if filters.is_empty() or Array(filters).any(
				func(part: String) -> bool: return part in path
		):
			var result: Result = \
					await run(path, _capture, verbose, tool_only or Engine.is_editor_hint())
			results.append(result)
			_print_result(result, verbose)
	
	OS.remove_logger(_capture)
	_capture = null
	_print_summary(results)
	return results


static func run(path: String, capture: Capture, verbose: bool, tool_only: bool) -> Result:
	var result: Result = Result.new(path)
	if verbose:
		print("Running %s" % path.trim_prefix(ROOT + "/"))
	
	capture.begin()
	var script: GDScript = load(path)
	if script != null and tool_only and not script.is_tool():
		capture.end()
		result.skip_reason = "runtime only"
		return result
	
	if script == null or not script.can_instantiate():
		result.failures = capture.end()
		result.failures.append(Failure.new(path, 0, "Script failed to compile"))
		return result
	
	if not script.has_script_method(ENTRY):
		capture.end()
		result.skip_reason = "no \"%s\" method found" % ENTRY
		return result
	
	var start: int = Time.get_ticks_usec()
	await script.call(ENTRY)
	result.seconds = (Time.get_ticks_usec() - start) / 1_000_000.0
	result.failures = capture.end()
	return result


static func expect_error(fragment: String) -> void:
	if _capture:
		_capture.expect(fragment)


static func fail(file: String, line: int, message: String) -> void:
	if _capture:
		_capture.add(Failure.new(file, line, message))
	else:
		push_error("%s:%d: %s" % [file, line, message])


static func find_tests(dir: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for entry: String in ResourceLoader.list_directory(dir):
		if entry.begins_with("_"):
			continue
		
		if entry.ends_with("/"):
			found.append_array(find_tests(dir.path_join(entry.trim_suffix("/"))))
		elif entry.get_extension() == "gd" and ResourceLoader.exists(dir.path_join(entry)):
			found.append(dir.path_join(entry))
	
	return found


static func count_failed(results: Array[Result]) -> int:
	return results.filter(func(result: Result) -> bool: return result.is_failed()).size()


static func _print_result(result: Result, verbose: bool) -> void:
	var name: String = result.get_name()
	if result.is_failed():
		print_rich("[color=red]FAIL[/color] %s" % name)
		for failure: Failure in result.failures:
			print_rich("    [color=red]%s[/color]" % failure)
	elif result.is_skipped() and verbose:
		print_rich("[color=yellow]SKIP[/color] %s (%s)" % [name, result.skip_reason])
	elif verbose:
		print_rich("[color=green]PASS[/color] %s (%.2fs)" % [name, result.seconds])


static func _print_summary(results: Array[Result]) -> void:
	var failed: int = count_failed(results)
	var skipped: int = \
			results.filter(func(result: Result) -> bool: return result.is_skipped()).size()
	var passed: int = results.size() - failed - skipped
	var color: String = "red" if failed > 0 else "green"
	print_rich(
			"[color=%s]%d passed, %d failed, %d skipped[/color]" % [
				color,
				passed,
				failed,
				skipped,
			]
	)


func _run_tests(verbose: bool) -> void:
	await run_all(verbose, "", true)


class Failure:
	var file: String
	var line: int
	var message: String
	
	
	func _init(failure_file: String, failure_line: int, failure_message: String) -> void:
		file = failure_file
		line = failure_line
		message = failure_message
	
	
	func _to_string() -> String:
		return message if file.is_empty() else "%s (%s:%d)" % [message, file, line]


class Result:
	var path: String
	var seconds: float = 0.0
	var skip_reason: String = ""
	var failures: Array[Failure] = []
	
	
	func _init(result_path: String) -> void:
		path = result_path
	
	
	func get_name() -> String:
		return path.trim_prefix(ROOT + "/").trim_suffix(".gd")
	
	
	func is_failed() -> bool:
		return not failures.is_empty()
	
	
	func is_skipped() -> bool:
		return not skip_reason.is_empty()


class Capture extends Logger:
	var _mutex: Mutex = Mutex.new()
	var _failures: Array[Failure] = []
	var _expected: PackedStringArray = []
	var _active: bool = false
	var _thread: int = 0
	
	
	func begin() -> void:
		_mutex.lock()
		_failures.clear()
		_expected.clear()
		_active = true
		_thread = OS.get_thread_caller_id()
		_mutex.unlock()
	
	
	func expect(fragment: String) -> void:
		_mutex.lock()
		_expected.append(fragment)
		_mutex.unlock()
	
	
	func add(failure: Failure) -> void:
		_mutex.lock()
		if _active:
			_failures.append(failure)
		_mutex.unlock()
	
	
	func end() -> Array[Failure]:
		_mutex.lock()
		var failures: Array[Failure] = _failures.duplicate()
		for fragment: String in _expected:
			failures.append(Failure.new("", 0, "Expected error was not raised: \"%s\"" % fragment))
		_active = false
		_mutex.unlock()
		return failures
	
	
	func _log_error(
			_function: String,
			file: String,
			line: int,
			code: String,
			rationale: String,
			_editor_notify: bool,
			error_type: int,
			script_backtraces: Array[ScriptBacktrace],
	) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		
		var message: String = rationale if not rationale.is_empty() else code
		for backtrace: ScriptBacktrace in script_backtraces:
			if backtrace.get_frame_count() > 0:
				file = backtrace.get_frame_file(0)
				line = backtrace.get_frame_line(0)
				break
		
		_mutex.lock()
		if OS.get_thread_caller_id() != _thread:
			_mutex.unlock()
			return
		
		var at: int = Array(_expected).find_custom(
				func(fragment: String) -> bool: return fragment in message
		)
		if at >= 0:
			_expected.remove_at(at)
		elif _active:
			_failures.append(Failure.new(file, line, message))
		_mutex.unlock()
