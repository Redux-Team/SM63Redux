const IGNORED: PackedStringArray = ["res://addons", "res://_local"]


static func find(extensions: PackedStringArray, dir: String = "res://") -> PackedStringArray:
	var found: PackedStringArray = []
	for file: String in DirAccess.get_files_at(dir):
		if extensions.has(file.get_extension()):
			found.append(dir.path_join(file))
	
	for sub: String in DirAccess.get_directories_at(dir):
		var path: String = dir.path_join(sub)
		if not sub.begins_with(".") and not IGNORED.has(path):
			found.append_array(find(extensions, path))
	
	return found


static func read(path: String) -> String:
	return FileAccess.get_file_as_string(path)
