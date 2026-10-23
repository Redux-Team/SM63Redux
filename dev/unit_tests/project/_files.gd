# this just makes it easier to quickly modify which unit tests are ran where,
# and ignore unnecessary files like addon and local ones
const IGNORED: PackedStringArray = ["res://addons", "res://_local"]
const LINT_IGNORED: PackedStringArray = [
	"res://addons",
	"res://_local",
	"res://dev/player_movement/player_old",
]


static func find(
		extensions: PackedStringArray,
		ignored: PackedStringArray = IGNORED,
		dir: String = "res://",
) -> PackedStringArray:
	var found: PackedStringArray = []
	for file: String in DirAccess.get_files_at(dir):
		if extensions.has(file.get_extension()):
			found.append(dir.path_join(file))
	
	for sub: String in DirAccess.get_directories_at(dir):
		var path: String = dir.path_join(sub)
		if not sub.begins_with(".") and not ignored.has(path):
			found.append_array(find(extensions, ignored, path))
	
	return found


static func read(path: String) -> String:
	return FileAccess.get_file_as_string(path)
