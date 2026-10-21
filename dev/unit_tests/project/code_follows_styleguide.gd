const Files: GDScript = preload("res://dev/unit_tests/project/_files.gd")
const PATTERNS: Dictionary[String, String] = {
	":=": "inferred declaration with \":=\"",
	"\\bemit_signal\\(": "emit_signal() instead of <signal>.emit()",
	"@onready": "@onready instead of an @export node reference",
	"(^|[\\s(\\[{,=!:])[$%][A-Za-z_\"]": "node path shorthand instead of an @export node reference",
}


static func run_test() -> void:
	var regexes: Dictionary[String, RegEx] = {}
	for pattern: String in PATTERNS:
		regexes.set(pattern, RegEx.create_from_string(pattern))
	
	for path: String in Files.find(["gd", "gdshader"]):
		var source: String = Files.read(path)
		var lines: PackedStringArray = source.split("\n")
		var is_script: bool = path.get_extension() == "gd"
		var string_lines: Dictionary[int, bool] = _find_string_lines(lines)
		if "\r" in source:
			_report(path, 1, "carriage return line endings")
		if not source.ends_with("\n") or source.ends_with("\n\n"):
			_report(path, lines.size(), "file must end with exactly one newline")
		
		var scanner: Scanner = Scanner.new()
		for i: int in lines.size() - 1:
			var line: String = lines.get(i)
			if string_lines.has(i):
				scanner.strip(line)
				continue
			
			if line.strip_edges().is_empty():
				if line != _get_next_indent(lines, i):
					_report(path, i + 1, "blank line must carry the indentation of the next line")
				continue
			
			if line.ends_with(" ") or line.ends_with("\t"):
				_report(path, i + 1, "trailing whitespace")
			if line.substr(0, line.length() - line.lstrip("\t ").length()).contains(" "):
				_report(path, i + 1, "indentation must use tabs")
			if not is_script:
				continue
			
			var code: String = scanner.strip(line)
			for pattern: String in PATTERNS:
				if regexes.get(pattern).search(code):
					_report(path, i + 1, PATTERNS.get(pattern))
			if line.begins_with("func ") or line.begins_with("static func "):
				_check_function_spacing(path, lines, i)


static func _find_string_lines(lines: PackedStringArray) -> Dictionary[int, bool]:
	var inside: Dictionary[int, bool] = {}
	var scanner: Scanner = Scanner.new()
	for i: int in lines.size():
		if scanner.is_open():
			inside.set(i, true)
		scanner.strip(lines.get(i))
	return inside


static func _get_next_indent(lines: PackedStringArray, from: int) -> String:
	for i: int in range(from + 1, lines.size()):
		var line: String = lines.get(i)
		if not line.strip_edges().is_empty():
			return line.substr(0, line.length() - line.lstrip("\t ").length())
	return ""


static func _check_function_spacing(path: String, lines: PackedStringArray, at: int) -> void:
	var top: int = at
	while top > 0 and (lines.get(top - 1).begins_with("@") or lines.get(top - 1).begins_with("#")):
		top -= 1
	
	var blanks: int = 0
	while top - blanks > 0 and lines.get(top - blanks - 1).is_empty():
		blanks += 1
	
	if top - blanks > 0 and blanks != 2:
		_report(path, at + 1, "functions must be separated by two blank lines")


static func _report(path: String, line: int, rule: String) -> void:
	UnitTester.fail(path, line, rule)


class Scanner:
	var _open: String = ""
	
	
	func is_open() -> bool:
		return not _open.is_empty()
	
	
	func strip(line: String) -> String:
		var code: String = ""
		var i: int = 0
		while i < line.length():
			var character: String = line.substr(i, 1)
			if is_open():
				if character == "\\":
					i += 2
				elif line.substr(i, _open.length()) == _open:
					code += _open
					i += _open.length()
					_open = ""
				else:
					i += 1
				continue
			
			if character == "#":
				break
			
			if character == "\"" or character == "'":
				var triple: String = character.repeat(3)
				_open = triple if line.substr(i, 3) == triple else character
				code += _open
				i += _open.length()
				continue
			
			code += character
			i += 1
		
		if _open.length() == 1:
			_open = ""
		return code
