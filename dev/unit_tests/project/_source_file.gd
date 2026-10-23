class_name SourceFile
extends RefCounted

var path: String = ""
var text: String = ""
var lines: PackedStringArray = []
var code: PackedStringArray = []
var strings: Array[PackedStringArray] = []
var columns: Array[PackedInt32Array] = []
var string_lines: Dictionary[int, bool] = {}
var open_brackets: Array[Array] = []


func _init(file_path: String) -> void:
	path = file_path
	text = FileAccess.get_file_as_string(file_path)
	lines = text.split("\n")
	_scan()


func is_script() -> bool:
	return path.get_extension() == "gd"


func get_indent(line: int) -> int:
	return lines[line].length() - lines[line].lstrip("\t").length()


func get_brackets(line: int) -> Array[Bracket]:
	var brackets: Array[Bracket] = []
	brackets.assign(open_brackets[line])
	return brackets


func is_blank(line: int) -> bool:
	return lines[line].strip_edges().is_empty()


func is_top_level(line: int) -> bool:
	return (
			not string_lines.has(line)
			and open_brackets[line].is_empty()
			and not lines[line].is_empty()
			and not lines[line][0] in "\t "
	)


func get_statement(line: int) -> String:
	var statement: String = code[line].strip_edges()
	var next: int = line + 1
	while next < lines.size() and is_continued(next):
		statement += " " + code[next].strip_edges()
		next += 1
	return statement


func is_continued(line: int) -> bool:
	return (
			not open_brackets[line].is_empty()
			or line > 0 and code[line - 1].strip_edges(false, true).ends_with("\\")
	)


func _scan() -> void:
	var quote: String = ""
	var stack: Array[Bracket] = []
	for i: int in lines.size():
		if not quote.is_empty():
			string_lines[i] = true
		open_brackets.append(stack.duplicate())
		var line: String = lines[i]
		var stripped: String = ""
		var found: PackedStringArray = []
		var mapping: PackedInt32Array = []
		var literal: String = ""
		var at: int = 0
		while at < line.length():
			var character: String = line[at]
			if not quote.is_empty():
				if character == "\\":
					literal += line.substr(at, 2)
					at += 2
				elif line.substr(at, quote.length()) == quote:
					found.append(quote + literal)
					stripped += quote
					for offset: int in quote.length():
						mapping.append(at + offset)
					at += quote.length()
					quote = ""
					literal = ""
				else:
					literal += character
					at += 1
				continue
			
			if character == "#":
				break
			
			if character == "\"" or character == "'":
				var triple: String = character.repeat(3)
				quote = triple if line.substr(at, 3) == triple else character
				stripped += quote
				for offset: int in quote.length():
					mapping.append(at + offset)
				at += quote.length()
				continue
			
			if character in "([{":
				var before: String = stripped.strip_edges(false, true).right(1)
				var word: RegEx = RegEx.create_from_string("\\w")
				var subscript: bool = character == "[" and (
						before == ")" or before == "]"
						or word.search(before) != null
				)
				stack.append(Bracket.new(character, get_indent(i), i, subscript))
			elif character in ")]}" and not stack.is_empty():
				stack.pop_back()
			stripped += character
			mapping.append(at)
			at += 1
		
		if quote.length() == 1:
			quote = ""
			literal = ""
		code.append(stripped)
		strings.append(found)
		columns.append(mapping)


class Bracket:
	var character: String = ""
	var indent: int = 0
	var line: int = 0
	var subscript: bool = false
	
	
	func _init(opening: String, opener_indent: int, opener_line: int, is_subscript: bool) -> void:
		character = opening
		indent = opener_indent
		line = opener_line
		subscript = is_subscript
	
	
	func is_continuation() -> bool:
		return character == "(" or subscript
