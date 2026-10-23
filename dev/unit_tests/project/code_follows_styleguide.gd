# TODO: mayyybe see if it'd be worth trying to enforce documentation on public
# methods/variables but that lowkey might be miserable to retroactively apply so
# idk
const Files: GDScript = preload("res://dev/unit_tests/project/_files.gd")
const MAX_WIDTH: int = 100
const TAB_WIDTH: int = 4
const PATTERNS: Dictionary[String, String] = {
	":=": "inferred declaration with \":=\"",
	"\\bemit_signal\\(": "emit_signal() instead of <signal>.emit()",
	"@onready": "@onready instead of an @export node reference",
	"(^|[\\s(\\[{,=!:])[$%][A-Za-z_\"]": (
			"node path shorthand instead of an @export node reference"
	),
	"&&|\\|\\|": "&& or || instead of and/or",
	"!(?!=)": "! instead of not",
	";": "more than one statement on a line",
	"[^=\\s]\\s*\\\\\\s*$": "backslash continuation is only for breaking after =",
	",(?=[^\\s)\\]}])": "missing space after a comma",
	"\\s,": "space before a comma",
	"[(\\[] +\\S|\\S +[)\\]]": "space inside parentheses or brackets",
	"\\S {2,}\\S": "more than one space between tokens",
	",\\s*[)\\]}]": "trailing comma in a single-line list",
	"(?<![\\w.])\\.\\d": "float without a leading zero",
	"(?<![\\w.])\\d+\\.(?![\\w.])": "float without a trailing zero",
	"\\b0(X|x[0-9a-fA-F_]*[A-F])": "uppercase hexadecimal",
	"(?<![\\w.])\\d{7,}(?![\\w.])": "large number without _ separators",
}
const HEADERS: String = "^\\s*(if|elif|while|for|else|match)\\b"
const NAMED_DEFINITION: String = "^\\t*((static\\s+)?func|class)\\s+\\w"
const WRAPPER: String = "^\\s*$|(?<![=!<>])=\\s*$|\\b(return|if|elif|while)\\s*$"


static func run_test() -> void:
	var regexes: Dictionary[String, RegEx] = {}
	for pattern: String in PATTERNS:
		regexes[pattern] = RegEx.create_from_string(pattern)
	
	for path: String in Files.find(["gd", "gdshader"], Files.LINT_IGNORED):
		var source: SourceFile = SourceFile.new(path)
		_check_file(source)
		var lambdas: Array[int] = []
		var continued: int = -1
		var covered: Array[int] = [-1]
		for i: int in source.lines.size() - 1:
			_check_width(source, i)
			if source.string_lines.has(i):
				continue
			
			if source.is_blank(i):
				_check_blank_line(source, i)
				continue
			
			_check_whitespace(source, i)
			if not source.is_script():
				continue
			
			var code: String = source.code[i]
			for pattern: String in PATTERNS:
				if regexes[pattern].search(code):
					_report(source, i, PATTERNS[pattern])
			_check_statement(source, i)
			_check_strings(source, i)
			_check_dictionaries(source, i)
			_check_continuation(source, i, lambdas)
			if continued >= 0 and source.get_indent(i) != continued + 2:
				_report(source, i, "the line after a backslash takes two indent levels")
			continued = -1
			if source.code[i].strip_edges(false, true).ends_with("\\"):
				continued = source.get_indent(i)
			_check_literal_lists(source, i)
			_check_wrapping(source, i, covered)
			if RegEx.create_from_string(NAMED_DEFINITION).search(source.lines[i]):
				_check_definition_spacing(source, i)


static func _check_file(source: SourceFile) -> void:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(source.path)
	if bytes.slice(0, 3) == PackedByteArray([0xef, 0xbb, 0xbf]):
		_report(source, 0, "UTF-8 byte order mark")
	if "\r" in source.text:
		_report(source, 0, "carriage return line endings")
	if not source.text.ends_with("\n") or source.text.ends_with("\n\n"):
		_report(source, source.lines.size() - 1, "file must end with exactly one newline")


static func _check_width(source: SourceFile, line: int) -> void:
	var width: int = _get_width(source.lines[line])
	if width > MAX_WIDTH:
		_report(source, line, "line is %d columns wide, limit is %d" % [width, MAX_WIDTH])


static func _check_blank_line(source: SourceFile, line: int) -> void:
	var next: int = line + 1
	while next < source.lines.size() and source.is_blank(next):
		next += 1
	
	var indent: String = ""
	if next < source.lines.size():
		var following: String = source.lines[next]
		indent = following.substr(0, following.length() - following.lstrip("\t ").length())
	if source.lines[line] != indent:
		_report(source, line, "blank line must carry the indentation of the next line")
	if line > 0 and source.is_blank(line - 1):
		return
	
	var run: int = next - line
	if indent.is_empty():
		if run > 2:
			_report(source, line, "more than two blank lines in a row")
	elif run > 1 and not _is_definition(source, next):
		_report(source, line, "more than one blank line inside a block")


static func _check_whitespace(source: SourceFile, line: int) -> void:
	var text: String = source.lines[line]
	if text.ends_with(" ") or text.ends_with("\t"):
		_report(source, line, "trailing whitespace")
	var indent: int = text.length() - text.lstrip("\t ").length()
	if text.substr(0, indent).contains(" "):
		_report(source, line, "indentation must use tabs")


static func _check_statement(source: SourceFile, line: int) -> void:
	var code: String = source.code[line].strip_edges()
	var header: RegExMatch = RegEx.create_from_string(HEADERS).search(code)
	var named: bool = RegEx.create_from_string("^(static\\s+)?func\\s+\\w").search(code) != null
	if header == null and not named:
		return
	
	var start: int = 0
	if named:
		start = code.find("(")
		start = _find_closing(code, start) if start >= 0 else code.length()
	elif header.get_string(1) == "for":
		start = code.find(" in ")
	var colon: int = _find_top_level(code, ":", maxi(start, 0))
	if colon >= 0 and not code.substr(colon + 1).strip_edges().is_empty():
		_report(source, line, "statement on the same line as its block header")
	
	if header != null and header.get_string(1) in ["if", "elif", "while"]:
		var condition: String = code.substr(header.get_end()).strip_edges()
		if (
				condition.begins_with("(")
				and condition.ends_with("):")
				and _find_closing(condition, 0) == condition.length() - 2
		):
			_report(source, line, "unnecessary parentheses around a condition")
	
	var wrapped: RegExMatch = \
			RegEx.create_from_string("(^|(?<![=!<>])=\\s*|\\breturn\\s+)\\(").search(code)
	if wrapped and _find_closing(code, wrapped.get_end() - 1) == code.length() - 1:
		_report(source, line, "unnecessary parentheses around an expression")


static func _check_strings(source: SourceFile, line: int) -> void:
	for literal: String in source.strings[line]:
		if literal.begins_with("'") and not literal.begins_with("'''"):
			if not "\"" in literal:
				_report(source, line, "single quotes instead of double quotes")


static func _check_dictionaries(source: SourceFile, line: int) -> void:
	var code: String = source.code[line]
	var stack: Array[int] = []
	for at: int in code.length():
		var character: String = code[at]
		if character in "([{":
			stack.append(at if character == "{" else -1)
		elif character in ")]}" and not stack.is_empty():
			var opening: int = stack.pop_back()
			if character != "}" or opening < 0:
				continue
			
			var inner: String = code.substr(opening + 1, at - opening - 1)
			if inner.strip_edges().is_empty():
				if not inner.is_empty():
					_report(source, line, "empty dictionary is written {}")
			elif not inner.begins_with(" ") or not inner.ends_with(" "):
				_report(source, line, "single-line dictionary needs spaces inside its braces")


static func _check_continuation(source: SourceFile, line: int, lambdas: Array[int]) -> void:
	var brackets: Array[SourceFile.Bracket] = source.get_brackets(line)
	var indent: int = source.get_indent(line)
	if brackets.is_empty():
		lambdas.clear()
		return
	
	while not lambdas.is_empty() and indent <= lambdas.back():
		lambdas.pop_back()
	if source.code[line].strip_edges().ends_with(":"):
		lambdas.append(indent)
	if lambdas.size() > (1 if source.code[line].strip_edges().ends_with(":") else 0):
		return
	
	var code: String = source.code[line].strip_edges()
	var closers: int = code.length() - code.lstrip(")]}").length()
	if closers > 0:
		var opener: SourceFile.Bracket = brackets[maxi(brackets.size() - closers, 0)]
		if indent != opener.indent:
			_report(source, line, "closing bracket must return to its opening line's indent")
		return
	
	var top: SourceFile.Bracket = brackets.back()
	var expected: int = top.indent + (2 if top.is_continuation() else 1)
	if indent == expected:
		return
	
	if top.is_continuation():
		_report(source, line, "continuation lines take two indent levels")
	else:
		_report(source, line, "array, dictionary and enum contents take one indent level")


static func _check_literal_lists(source: SourceFile, line: int) -> void:
	var code: String = source.code[line].strip_edges()
	if RegEx.create_from_string("^enum\\b[^{]*\\{.*\\S.*\\}").search(code):
		_report(source, line, "enum members go on their own lines")
	
	var brackets: Array[SourceFile.Bracket] = source.get_brackets(line)
	if brackets.is_empty():
		return
	
	var top: SourceFile.Bracket = brackets.back()
	var opener: String = source.code[top.line]
	if (
			top.character == "{"
			and RegEx.create_from_string("\\benum\\b").search(opener)
			and not code.begins_with("}")
			and "," in code.trim_suffix(",")
	):
		_report(source, line, "enum members go on their own lines")
	if not (code.begins_with("]") or code.begins_with("}")):
		return
	if top.is_continuation() or top.line == line:
		return
	
	var previous: int = line - 1
	while previous > top.line and source.code[previous].strip_edges().is_empty():
		previous -= 1
	if previous > top.line and not source.code[previous].strip_edges().ends_with(","):
		_report(source, previous, "multi-line array, dictionary or enum needs a trailing comma")


static func _check_definition_spacing(source: SourceFile, line: int) -> void:
	var indent: int = source.get_indent(line)
	var top: int = line
	while top > 0 and source.lines[top - 1].strip_edges().left(1) in ["@", "#"]:
		top -= 1
	
	var blanks: int = 0
	while top - blanks > 0 and source.is_blank(top - blanks - 1):
		blanks += 1
	
	var above: int = top - blanks - 1
	if above < 0:
		return
	if indent > 0 and source.get_indent(above) < indent:
		return
	if blanks != 2:
		_report(source, line, "functions and classes must be separated by two blank lines")


static func _check_wrapping(source: SourceFile, line: int, covered: Array[int]) -> void:
	if line <= covered[0]:
		return
	
	var code: String = source.code[line].strip_edges(false, true)
	if code.ends_with("\\"):
		_check_backslash(source, line)
		return
	if not code.ends_with("(") and not (code.ends_with("[") and _is_subscript(code)):
		return
	
	var closing: int = _find_closing_line(source, line)
	var joined: String = _join(source, line, closing)
	if joined.is_empty():
		return
	
	var statement: bool = source.get_brackets(line).is_empty() and not source.is_continued(line)
	if statement:
		joined = _drop_wrapper(source, line, closing, joined)
	if _get_width(joined) <= MAX_WIDTH:
		covered[0] = closing
		_report(source, line, "this fits on one line within %d columns" % MAX_WIDTH)


static func _check_backslash(source: SourceFile, line: int) -> void:
	var next: int = line + 1
	if next >= source.lines.size() or _has_comment(source, line):
		return
	
	var following: String = source.code[next].strip_edges(false, true)
	if following.right(1) in ["(", "[", "{", "\\"]:
		return
	
	var head: String = source.lines[line].strip_edges(false, true).trim_suffix("\\")
	var joined: String = head.strip_edges(false, true) + " " + source.lines[next].strip_edges()
	if _get_width(joined) <= MAX_WIDTH:
		_report(source, line, "this fits on one line within %d columns" % MAX_WIDTH)


static func _is_definition(source: SourceFile, line: int) -> bool:
	var at: int = line
	while at < source.lines.size() and source.lines[at].strip_edges().left(1) in ["@", "#"]:
		at += 1
	return (
			at < source.lines.size()
			and RegEx.create_from_string(NAMED_DEFINITION).search(source.lines[at]) != null
	)


static func _find_closing_line(source: SourceFile, line: int) -> int:
	var depth: int = 1
	for at: int in range(line + 1, source.lines.size()):
		for character: String in source.code[at]:
			if character in "([{":
				depth += 1
			elif character in ")]}":
				depth -= 1
				if depth == 0:
					return at
	return -1


static func _join(source: SourceFile, start: int, end: int) -> String:
	if end < 0:
		return ""
	
	for at: int in range(start, end + 1):
		if source.string_lines.has(at) or source.is_blank(at) or _has_comment(source, at):
			return ""
		if at == start or at == end:
			continue
		
		var inner: String = source.code[at].strip_edges(false, true)
		if inner.right(1) in [":", "{", "\\"]:
			return ""
		if inner.ends_with("[") and not _is_subscript(inner):
			return ""
	
	var result: String = source.lines[start].strip_edges(false, true)
	for at: int in range(start + 1, end + 1):
		var piece: String = source.lines[at].strip_edges()
		if result.right(1) in ["(", "["]:
			result += piece
		elif piece.left(1) in [")", "]", "}"]:
			result = result.trim_suffix(",") + piece
		elif piece.begins_with("."):
			result += piece
		else:
			result += " " + piece
	return result


static func _drop_wrapper(source: SourceFile, start: int, end: int, joined: String) -> String:
	var code: String = source.code[start].strip_edges(false, true)
	var closer: String = source.code[end].strip_edges()
	if not code.ends_with("(") or not closer in [")", "):"]:
		return joined
	if not RegEx.create_from_string(WRAPPER).search(code.left(code.length() - 1)):
		return joined
	
	var opening: String = source.lines[start].strip_edges(false, true)
	var head: String = opening.left(opening.length() - 1).strip_edges(false, true)
	var tail: String = ":" if closer == "):" else ""
	var inner: String = joined.substr(opening.length())
	inner = inner.left(inner.length() - 1 - tail.length()).strip_edges()
	if head.strip_edges().is_empty():
		return head + inner
	return head + " " + inner + tail


static func _has_comment(source: SourceFile, line: int) -> bool:
	var mapping: PackedInt32Array = source.columns[line]
	if mapping.is_empty():
		return not source.is_blank(line)
	return source.lines[line].substr(mapping[-1] + 1).strip_edges().begins_with("#")


static func _is_subscript(code: String) -> bool:
	var before: String = code.left(code.length() - 1).strip_edges(false, true).right(1)
	return before == ")" or before == "]" or RegEx.create_from_string("\\w").search(before) != null


static func _find_closing(text: String, opening: int) -> int:
	var depth: int = 0
	for at: int in range(opening, text.length()):
		if text[at] in "([{":
			depth += 1
		elif text[at] in ")]}":
			depth -= 1
			if depth == 0:
				return at
	return -1


static func _find_top_level(text: String, target: String, from: int) -> int:
	var depth: int = 0
	for at: int in range(from, text.length()):
		if text[at] in "([{":
			depth += 1
		elif text[at] in ")]}":
			depth -= 1
		elif depth == 0 and text[at] == target:
			return at
	return -1


static func _get_width(line: String) -> int:
	var width: int = 0
	for character: String in line:
		width += TAB_WIDTH - width % TAB_WIDTH if character == "\t" else 1
	return width


static func _report(source: SourceFile, line: int, rule: String) -> void:
	UnitTester.fail(source.path, line + 1, rule)
