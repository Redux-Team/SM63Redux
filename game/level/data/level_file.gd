@tool
class_name LevelFile

const EXTENSION_BINARY: String = "63rl"
const EXTENSION_JSON: String = "json"


static func read(path: String) -> LevelData:
	var dict: Variant = _read_json(path) if path.get_extension() == EXTENSION_JSON else _read_binary(path)
	if dict is not Dictionary:
		push_error("LevelFile: could not read '%s'." % path)
		return null
	
	return LevelData.from_dict(dict)


static func write(path: String, data: LevelData) -> Error:
	if path.get_extension() == EXTENSION_JSON:
		var text_file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if text_file == null:
			return FileAccess.get_open_error()
		text_file.store_string(JSON.stringify(JSON.from_native(data.to_dict()), "\t"))
		return OK
	
	var file: FileAccess = FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return FileAccess.get_open_error()
	file.store_var(data.to_dict())
	return OK


static func _read_json(path: String) -> Variant:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return null
	return JSON.to_native(JSON.parse_string(text))


static func _read_binary(path: String) -> Variant:
	var file: FileAccess = FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return null
	return file.get_var()
