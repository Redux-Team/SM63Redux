class_name ObjectSceneFile
extends RefCounted

const DEFAULTS: Dictionary[StringName, Variant] = {
	&"display_name": "",
	&"category": &"",
	&"group": &"",
	&"biome": &"",
	&"order": 0,
	&"placement": 1,
	&"browsable": true,
	&"unique": false,
	&"flags": 31,
}

var path: String
var _lines: PackedStringArray


static func open(scene_path: String) -> ObjectSceneFile:
	var text: String = FileAccess.get_file_as_string(scene_path)
	if text.is_empty():
		return null
	
	var file: ObjectSceneFile = ObjectSceneFile.new()
	file.path = scene_path
	file._lines = text.split("\n")
	return file


static func encode(value: Variant) -> String:
	if value is StringName:
		return "&\"%s\"" % String(value).c_escape()
	if value is String:
		return "\"%s\"" % (value as String).c_escape()
	if value is bool:
		return "true" if value else "false"
	
	return str(value)


func set_value(key: StringName, value: Variant) -> void:
	var block: Vector2i = _root_block()
	var line: String = "%s = %s" % [key, encode(value)]
	var existing: int = _find(key, block)
	var is_default: bool = DEFAULTS.has(key) and DEFAULTS[key] == value and key != &"display_name"
	if existing >= 0:
		if is_default:
			_lines.remove_at(existing)
		else:
			_lines[existing] = line
		return
	
	if not is_default:
		_lines.insert(_insert_index(block), line)


func set_icon(texture_path: String, region: Rect2) -> void:
	var texture_id: String = _ensure_ext_resource("Texture2D", texture_path)
	var block: Vector2i = _root_block()
	var icon_line: int = _find(&"icon", block)
	var atlas_id: String = ""
	if icon_line >= 0 and _lines[icon_line].contains("SubResource(\""):
		atlas_id = _lines[icon_line].get_slice("\"", 1)
	var header: int = (
			_find_header("[sub_resource type=\"AtlasTexture\" id=\"%s\"]" % atlas_id)
			if not atlas_id.is_empty()
			else -1
	)
	var body: PackedStringArray = [
		"atlas = ExtResource(\"%s\")" % texture_id,
		"region = Rect2(%d, %d, %d, %d)" % [
			region.position.x,
			region.position.y,
			region.size.x,
			region.size.y,
		],
	]
	if header >= 0:
		var end: int = header + 1
		while (
				end < _lines.size()
				and not _lines[end].strip_edges().is_empty()
				and not _lines[end].begins_with("[")
		):
			end += 1
		for i: int in end - header - 1:
			_lines.remove_at(header + 1)
		for i: int in body.size():
			_lines.insert(header + 1 + i, body[i])
		return
	
	atlas_id = _unique_id("IconAtlas")
	var at: int = _root_block().x
	_lines.insert(at, "")
	var atlas_line: String = "[sub_resource type=\"AtlasTexture\" id=\"%s\"]" % atlas_id
	var inserted: PackedStringArray = PackedStringArray([atlas_line]) + body
	for i: int in inserted.size():
		_lines.insert(at + i, inserted[i])
	block = _root_block()
	icon_line = _find(&"icon", block)
	var line: String = "icon = SubResource(\"%s\")" % atlas_id
	if icon_line >= 0:
		_lines[icon_line] = line
	else:
		_lines.insert(_insert_index(block), line)


func save() -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	
	file.store_string("\n".join(_lines))
	return OK


func duplicate_as(new_path: String, new_id: StringName, new_name: String) -> ObjectSceneFile:
	var copy: ObjectSceneFile = ObjectSceneFile.new()
	copy.path = new_path
	copy._lines = _lines.duplicate()
	copy._lines[0] = copy._lines[0].replace(_uid_attribute(copy._lines[0]), "")
	copy.set_value(&"id", new_id)
	copy.set_value(&"display_name", new_name)
	return copy


func _ensure_ext_resource(type: String, resource_path: String) -> String:
	var last: int = -1
	for i: int in _lines.size():
		var line: String = _lines[i]
		if line.begins_with("[ext_resource "):
			last = i
			if line.contains("path=\"%s\"" % resource_path):
				return line.get_slice(" id=\"", 1).get_slice("\"", 0)
	
	var id: String = _unique_id("icon_texture")
	var line: String = "[ext_resource type=\"%s\" path=\"%s\" id=\"%s\"]" % [
		type,
		resource_path,
		id,
	]
	if last >= 0:
		_lines.insert(last + 1, line)
	else:
		_lines.insert(1, "")
		_lines.insert(2, line)
	return id


func _find_header(header: String) -> int:
	for i: int in _lines.size():
		if _lines[i] == header:
			return i
	
	return -1


func _unique_id(base: String) -> String:
	var id: String = base
	var n: int = 2
	while Array(_lines).any(
			func(line: String) -> bool:
				return (line.begins_with("[") and line.contains(" id=\"%s\"" % id))
	):
		id = "%s_%d" % [base, n]
		n += 1
	
	return id


func _uid_attribute(header: String) -> String:
	var start: int = header.find(" uid=\"")
	return header.substr(start, header.find("\"", start + 6) - start + 1) if start >= 0 else ""


func _root_block() -> Vector2i:
	var start: int = -1
	for i: int in _lines.size():
		var line: String = _lines[i]
		if start < 0 and line.begins_with("[node "):
			start = i
		elif start >= 0 and line.begins_with("["):
			return Vector2i(start, i)
	
	return Vector2i(start, _lines.size())


func _find(key: StringName, block: Vector2i) -> int:
	for i: int in range(block.x + 1, block.y):
		if _lines[i].begins_with("%s = " % key):
			return i
	
	return -1


func _insert_index(block: Vector2i) -> int:
	var after: int = block.x
	for i: int in range(block.x + 1, block.y):
		var line: String = _lines[i]
		if (
				line.begins_with("script = ")
				or DEFAULTS.has(StringName(line.get_slice(" = ", 0)))
				or line.begins_with("id = ")
		):
			after = i
	
	return after + 1
