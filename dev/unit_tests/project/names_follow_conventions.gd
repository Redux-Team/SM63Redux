const Files: GDScript = preload("res://dev/unit_tests/project/_files.gd")
const SNAKE_CASE: String = "^_?[a-z][a-z0-9_]*$"
const CONSTANT_CASE: String = "^_?[A-Z][A-Z0-9_]*$"
const PASCAL_CASE: String = "^[A-Z][A-Za-z0-9]*$"
const DECLARATIONS: Dictionary[String, String] = {
	"^(?:@\\w+(?:\\([^)]*\\))?\\s+)*(?:static\\s+)?var\\s+(\\w+)": "variable",
	"^(?:static\\s+)?func\\s+(\\w+)": "function",
	"^signal\\s+(\\w+)": "signal",
	"^for\\s+(\\w+)": "loop variable",
	"^const\\s+(\\w+)": "constant",
	"^enum\\s+(\\w+)": "enum",
	"^class\\s+(\\w+)": "class",
	"^class_name\\s+(\\w+)": "class_name",
}
const STYLES: Dictionary[String, String] = {
	"variable": SNAKE_CASE,
	"function": SNAKE_CASE,
	"signal": SNAKE_CASE,
	"loop variable": SNAKE_CASE,
	"parameter": SNAKE_CASE,
	"constant": CONSTANT_CASE,
	"enum": PASCAL_CASE,
	"enum member": CONSTANT_CASE,
	"class": PASCAL_CASE,
	"class_name": PASCAL_CASE,
}
const STYLE_NAMES: Dictionary[String, String] = {
	SNAKE_CASE: "snake_case",
	CONSTANT_CASE: "CONSTANT_CASE",
	PASCAL_CASE: "PascalCase",
}


static func run_test() -> void:
	var regexes: Dictionary[String, RegEx] = {}
	for pattern: String in DECLARATIONS:
		regexes[pattern] = RegEx.create_from_string(pattern)
	
	for path: String in Files.find(["gd"], Files.LINT_IGNORED):
		var source: SourceFile = SourceFile.new(path)
		for i: int in source.lines.size():
			if source.string_lines.has(i):
				continue
			
			var code: String = source.code[i].strip_edges()
			for pattern: String in DECLARATIONS:
				var found: RegExMatch = regexes[pattern].search(code)
				if found:
					_check_name(source, i, DECLARATIONS[pattern], found, code)
			_check_parameters(source, i)
			_check_enum_member(source, i)


static func _check_name(
		source: SourceFile,
		line: int,
		kind: String,
		found: RegExMatch,
		code: String,
) -> void:
	var name: String = found.get_string(1)
	var style: String = STYLES[kind]
	if kind == "constant" and RegEx.create_from_string("=\\s*(preload|load)\\(").search(code):
		style = "%s|%s" % [CONSTANT_CASE, PASCAL_CASE]
	if not RegEx.create_from_string(style).search(name):
		_report(source, line, kind, name, style)
	if kind == "class_name":
		var file: String = source.path.get_file().get_basename()
		if file.trim_prefix("_") != name.to_snake_case():
			UnitTester.fail(
					source.path,
					line + 1,
					"class_name %s belongs in %s.gd" % [
						name,
						name.to_snake_case(),
					],
			)


static func _check_parameters(source: SourceFile, line: int) -> void:
	var code: String = source.code[line]
	var brackets: Array[SourceFile.Bracket] = source.get_brackets(line)
	if not brackets.is_empty():
		var top: SourceFile.Bracket = brackets.back()
		if (
				top.character == "("
				and RegEx.create_from_string("\\b(func|signal)\\b").search(source.code[top.line])
				and not RegEx.create_from_string("\\bfunc\\s*\\(").search(code)
		):
			var item: RegExMatch = RegEx.create_from_string("^\\s*(\\w+)\\s*[:=,)]").search(code)
			if item:
				_check_parameter(source, line, item.get_string(1))
	
	for header: RegExMatch in RegEx.create_from_string(
			"\\b(func|signal)\\b\\s*\\w*\\s*\\("
	).search_all(code):
		var depth: int = 1
		var start: int = header.get_end()
		var at: int = start
		var expect_name: bool = true
		while at < code.length() and depth > 0:
			var character: String = code[at]
			if character in "([{":
				depth += 1
			elif character in ")]}":
				depth -= 1
			elif depth == 1 and character == ",":
				expect_name = true
			elif expect_name and RegEx.create_from_string("\\w").search(character):
				var name: RegExMatch = RegEx.create_from_string("\\w+").search(code, at)
				_check_parameter(source, line, name.get_string())
				at = name.get_end() - 1
				expect_name = false
			at += 1


static func _check_parameter(source: SourceFile, line: int, name: String) -> void:
	if not RegEx.create_from_string(SNAKE_CASE).search(name):
		_report(source, line, "parameter", name, SNAKE_CASE)


static func _check_enum_member(source: SourceFile, line: int) -> void:
	var brackets: Array[SourceFile.Bracket] = source.get_brackets(line)
	if brackets.is_empty():
		return
	
	var top: SourceFile.Bracket = brackets.back()
	if (
			top.character != "{"
			or not RegEx.create_from_string("^\\s*enum\\b").search(source.code[top.line])
	):
		return
	
	var member: RegExMatch = RegEx.create_from_string("^\\s*(\\w+)").search(source.code[line])
	if member and not RegEx.create_from_string(CONSTANT_CASE).search(member.get_string(1)):
		_report(source, line, "enum member", member.get_string(1), CONSTANT_CASE)


static func _report(
		source: SourceFile,
		line: int,
		kind: String,
		name: String,
		style: String,
) -> void:
	var expected: String = STYLE_NAMES.get(style, "CONSTANT_CASE or PascalCase")
	UnitTester.fail(source.path, line + 1, "%s %s should be %s" % [kind, name, expected])
