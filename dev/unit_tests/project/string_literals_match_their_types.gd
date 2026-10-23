const Files: GDScript = preload("res://dev/unit_tests/project/_files.gd")
const PREFIXES: Dictionary[int, String] = {
	TYPE_STRING: "",
	TYPE_STRING_NAME: "&",
	TYPE_NODE_PATH: "^",
}
const TYPE_NAMES: Dictionary[String, int] = {
	"String": TYPE_STRING,
	"StringName": TYPE_STRING_NAME,
	"NodePath": TYPE_NODE_PATH,
}
const AMBIGUOUS: PackedStringArray = [
	"append", "begins_with", "bind", "bsearch", "call", "callv", "contains",
	"count", "ends_with",
	"erase", "fill", "find", "find_key", "format", "get", "get_or_add", "has",
	"insert", "is_empty", "join", "left", "lstrip", "match", "push_back",
	"push_front", "remove_at", "replace", "rfind", "right", "rstrip", "set",
	"split", "strip_edges", "substr", "trim_prefix", "trim_suffix",
]
const KEYWORDS: PackedStringArray = [
	"and", "elif", "if", "in", "not", "or", "return", "while",
]
const STRING_TYPES: String = "(String|StringName|NodePath)"


static func run_test() -> void:
	var methods: Dictionary[String, Array] = _index_methods()
	for path: String in Files.find(["gd"], Files.LINT_IGNORED):
		_check_file(SourceFile.new(path), methods)


static func _index_methods() -> Dictionary[String, Array]:
	var methods: Dictionary[String, Array] = {}
	for native: StringName in ClassDB.get_class_list():
		for method: Dictionary in ClassDB.class_get_method_list(native, true):
			_add_method(methods, method)
	
	var paths: PackedStringArray = Files.find(["gd"], Files.LINT_IGNORED)
	for info: Dictionary in ProjectSettings.get_global_class_list():
		var path: String = info["path"]
		if path.begins_with("res://addons") and not "/editor/" in path:
			paths.append(path)
	for path: String in paths:
		var script: Script = load(path) as Script
		if script == null:
			continue
		
		for method: Dictionary in script.get_script_method_list():
			_add_method(methods, method)
	return methods


static func _add_method(methods: Dictionary[String, Array], method: Dictionary) -> void:
	var signature: PackedInt32Array = [method["return"]["type"]]
	for argument: Dictionary in method["args"]:
		signature.append(argument["type"])
	if not methods.has(method["name"]):
		methods[method["name"]] = []
	methods[method["name"]].append(signature)


static func _check_file(source: SourceFile, methods: Dictionary[String, Array]) -> void:
	var declared: Dictionary[String, int] = \
			_find_declarations(source, "(\\w+)\\s*:\\s*%s\\b(?!\\s*[\\[(])" % STRING_TYPES)
	var keys: Dictionary[String, int] = \
			_find_declarations(source, "(\\w+)\\s*:\\s*Dictionary\\[%s\\s*," % STRING_TYPES)
	var context: Context = Context.new(source, declared, keys, methods)
	var line: int = 0
	while line < source.lines.size():
		if source.string_lines.has(line) or source.is_continued(line):
			line += 1
			continue
		
		var statement: Statement = Statement.new(source, line)
		var header: RegExMatch = \
				RegEx.create_from_string("^\\s*(static\\s+)?func\\s+\\w+").search(statement.text)
		if header:
			var returned: RegExMatch = \
					RegEx.create_from_string("->\\s*(\\w+)\\s*:").search(statement.text)
			var type: String = returned.get_string(1) if returned else ""
			context.returns = TYPE_NAMES.get(type, -1)
		
		for literal: RegExMatch in RegEx.create_from_string(
				"(?<![\\w\"'])([&^r]?)(\"\"|'')(?![\"'])"
		).search_all(statement.text):
			_check_literal(source, statement, literal, context)
		line = statement.end


static func _find_declarations(source: SourceFile, pattern: String) -> Dictionary[String, int]:
	var found: Dictionary[String, int] = {}
	var regex: RegEx = RegEx.create_from_string(pattern)
	for line: int in source.lines.size():
		if source.string_lines.has(line):
			continue
		
		for declaration: RegExMatch in regex.search_all(source.code[line]):
			var name: String = declaration.get_string(1)
			var type: int = TYPE_NAMES[declaration.get_string(2)]
			found[name] = type if found.get(name, type) == type else -2
	return found


static func _check_literal(
		source: SourceFile,
		statement: Statement,
		literal: RegExMatch,
		context: Context,
) -> void:
	var expected: int = \
			_expected_type(statement.text, literal.get_start(), literal.get_end(), context)
	if not PREFIXES.has(expected):
		return
	
	var prefix: String = literal.get_string(1).replace("r", "")
	if prefix == PREFIXES[expected]:
		return
	
	var position: Vector2i = statement.locate(literal.get_start())
	UnitTester.fail(
			source.path,
			position.x + 1,
			"%s literal should be written %s\"\" (column %d)" % [
				type_string(expected),
				PREFIXES[expected],
				position.y + 1,
			],
	)


static func _expected_type(text: String, start: int, end: int, context: Context) -> int:
	var before: String = text.substr(0, start)
	var after: String = text.substr(end).strip_edges(true, false)
	var match_before: Callable = func(pattern: String) -> RegExMatch:
		return RegEx.create_from_string(pattern + "$").search(before)
	
	var typed: RegExMatch = match_before.call("\\b\\w+\\s*:\\s*%s\\s*=\\s*" % STRING_TYPES)
	if typed:
		return TYPE_NAMES[typed.get_string(1)]
	
	var assigned: RegExMatch = \
			match_before.call("(?:\\bself\\.)?\\b(\\w+)\\s*(?<![=!<>:+\\-*/%&|^])=\\s*")
	if assigned:
		return context.declared.get(assigned.get_string(1), -1)
	
	var compared: RegExMatch = match_before.call("(==|!=)\\s*")
	if compared:
		var left: String = before.substr(0, compared.get_start())
		return _expected_operand(left, context)
	
	var lambda: RegExMatch = match_before.call("->\\s*%s\\s*:\\s*return\\s+" % STRING_TYPES)
	if lambda:
		return TYPE_NAMES[lambda.get_string(1)]
	if match_before.call("\\breturn\\s+"):
		return context.returns
	return _expected_element(text, start, after, context)


static func _expected_operand(left: String, context: Context) -> int:
	var trimmed: String = left.strip_edges(false, true)
	if trimmed.ends_with(")"):
		var opening: int = _find_opening(trimmed, trimmed.length() - 1)
		if opening < 0:
			return -1
		return context.get_call_type(trimmed.substr(0, opening), -1)
	
	var variable: RegExMatch = \
			RegEx.create_from_string("(?:^|[^\\w.]|\\bself\\.)(\\w+)$").search(trimmed)
	if variable:
		return context.declared.get(variable.get_string(1), -1)
	return -1


static func _expected_element(text: String, start: int, after: String, context: Context) -> int:
	var depth: int = 0
	var commas: int = 0
	var opening: int = -1
	for at: int in range(start - 1, -1, -1):
		var character: String = text[at]
		if character in ")]}":
			depth += 1
		elif character in "([{":
			if depth == 0:
				opening = at
				break
			depth -= 1
		elif character == "," and depth == 0:
			commas += 1
	if opening < 0:
		return -1
	
	var lead: String = text.substr(opening + 1, start - opening - 1)
	var since_comma: String = lead.substr(lead.rfind(",") + 1)
	var outside: String = text.substr(0, opening).strip_edges(false, true)
	var bracket: String = text[opening]
	if bracket == "{":
		var dictionary: RegExMatch = RegEx.create_from_string(
				"Dictionary\\[(\\w+)\\s*,\\s*(\\w+)\\]\\s*=$"
		).search(outside)
		if dictionary == null:
			return -1
		if since_comma.strip_edges().is_empty() and after.begins_with(":"):
			return TYPE_NAMES.get(dictionary.get_string(1), -1)
		if since_comma.strip_edges().ends_with(":") and after.left(1) in [",", "}", ""]:
			return TYPE_NAMES.get(dictionary.get_string(2), -1)
		return -1
	
	if not since_comma.strip_edges().is_empty():
		return -1
	if not after.left(1) in [",", ")", "]", ""]:
		return -1
	
	var name: RegExMatch = RegEx.create_from_string("(\\w+)$").search(outside)
	if bracket == "[":
		var array: RegExMatch = RegEx.create_from_string(
				"(?:Array\\[%s\\]|(PackedStringArray))\\s*=$" % STRING_TYPES
		).search(outside)
		if array:
			return TYPE_STRING if array.get_string(2) else TYPE_NAMES[array.get_string(1)]
		if name:
			return context.keys.get(name.get_string(1), -1)
		return -1
	
	if name == null or KEYWORDS.has(name.get_string(1)):
		return -1
	if RegEx.create_from_string("\\bfunc\\s*\\w*$").search(outside):
		return -1
	return context.get_call_type(outside, commas)


static func _find_opening(text: String, closing: int) -> int:
	var depth: int = 0
	for at: int in range(closing, -1, -1):
		if text[at] in ")]}":
			depth += 1
		elif text[at] in "([{":
			depth -= 1
			if depth == 0:
				return at
	return -1


class Statement:
	var text: String = ""
	var end: int = 0
	var _source: SourceFile
	var _starts: PackedInt32Array = []
	var _lines: PackedInt32Array = []
	
	
	func _init(source: SourceFile, start: int) -> void:
		_source = source
		end = start
		while true:
			_starts.append(text.length())
			_lines.append(end)
			text += source.code[end] + " "
			end += 1
			if end >= source.lines.size() or not source.is_continued(end):
				break
	
	
	func locate(offset: int) -> Vector2i:
		var index: int = _starts.bsearch(offset, false) - 1
		var line: int = _lines[index]
		return Vector2i(line, _source.columns[line][offset - _starts[index]])


class Context:
	var declared: Dictionary[String, int] = {}
	var keys: Dictionary[String, int] = {}
	var returns: int = -1
	var _methods: Dictionary[String, Array] = {}
	var _types: Dictionary[String, String] = {}
	var _globals: Dictionary[String, String] = {}
	var _script: Script
	
	
	func _init(
			source: SourceFile,
			declared_types: Dictionary[String, int],
			key_types: Dictionary[String, int],
			methods: Dictionary[String, Array],
	) -> void:
		declared = declared_types
		keys = key_types
		_methods = methods
		_script = load(source.path) as Script
		var regex: RegEx = RegEx.create_from_string("(\\w+)\\s*:\\s*([A-Z]\\w*)\\b(?!\\s*[\\[(.])")
		for line: int in source.lines.size():
			for declaration: RegExMatch in regex.search_all(source.code[line]):
				var name: String = declaration.get_string(1)
				var type: String = declaration.get_string(2)
				_types[name] = type if _types.get(name, type) == type else ""
	
	
	func get_call_type(callee: String, argument: int) -> int:
		var call: RegExMatch = RegEx.create_from_string(
				"(?:(?<![\\w.)\\]])(\\w+)\\s*\\.\\s*)?(\\w+)\\s*$"
		).search(callee)
		if call == null:
			return -1
		
		var method: String = call.get_string(2)
		var receiver: String = call.get_string(1)
		var trimmed: String = callee.strip_edges(false, true)
		var dotted: bool = trimmed.trim_suffix(method).ends_with(".")
		var signature: PackedInt32Array = \
				_resolve(receiver if dotted or not receiver.is_empty() else "self", method)
		if not signature.is_empty():
			if signature.size() <= argument + 1:
				return -1
			return signature[argument + 1]
		if not receiver.is_empty() and not _types.get(receiver, "").is_empty():
			return -1
		return _get_agreed_type(method, argument)
	
	
	func _resolve(receiver: String, method: String) -> PackedInt32Array:
		var script: Script = null
		var native: String = ""
		if receiver == "self":
			script = _script
		elif receiver.is_empty():
			return PackedInt32Array()
		elif ProjectSettings.has_setting("autoload/" + receiver):
			var setting: String = "autoload/" + receiver
			var autoload: String = ProjectSettings.get_setting(setting)
			script = load(autoload.trim_prefix("*")) as Script
		else:
			var type: String = receiver
			if not (ClassDB.class_exists(type) or _find_global(type)):
				type = _types.get(receiver, "")
			if type.is_empty():
				return PackedInt32Array()
			if ClassDB.class_exists(type):
				native = type
			else:
				script = _find_global(type)
			if script == null and native.is_empty():
				return PackedInt32Array()
		if script:
			for entry: Dictionary in script.get_script_method_list():
				if entry["name"] == method:
					return _signature_of(entry)
			native = script.get_instance_base_type()
		if native.is_empty() or not ClassDB.class_has_method(native, method):
			return PackedInt32Array()
		
		for entry: Dictionary in ClassDB.class_get_method_list(native):
			if entry["name"] == method:
				return _signature_of(entry)
		return PackedInt32Array()
	
	
	func _get_agreed_type(method: String, argument: int) -> int:
		if AMBIGUOUS.has(method) or not _methods.has(method):
			return -1
		
		var found: int = -1
		for signature: PackedInt32Array in _methods[method]:
			if signature.size() <= argument + 1:
				continue
			
			var type: int = signature[argument + 1]
			if type == TYPE_NIL:
				return -1
			if not PREFIXES.has(type):
				continue
			if found >= 0 and found != type:
				return -1
			found = type
		return found
	
	
	func _find_global(type: String) -> Script:
		if _globals.is_empty():
			for info: Dictionary in ProjectSettings.get_global_class_list():
				_globals[info["class"]] = info["path"]
		return load(_globals[type]) as Script if _globals.has(type) else null
	
	
	func _signature_of(entry: Dictionary) -> PackedInt32Array:
		var signature: PackedInt32Array = [entry["return"]["type"]]
		for argument: Dictionary in entry["args"]:
			signature.append(argument["type"])
		return signature
