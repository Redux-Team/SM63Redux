const Files: GDScript = preload("res://dev/unit_tests/project/_files.gd")
const SNAKE_CASE: String = "^_?[a-z0-9]+(_[a-z0-9]+)*$"
const DOCUMENT_CASE: String = "^[A-Z]+$"
const DOCUMENTS: PackedStringArray = ["md", "txt"]
const MIRRORS: PackedStringArray = ["uid", "import"]


static func run_test() -> void:
	_check_directory("res://")


static func _check_directory(dir: String) -> void:
	for file: String in DirAccess.get_files_at(dir):
		if not MIRRORS.has(file.get_extension()):
			_check_name(dir.path_join(file), "file")
	
	for sub: String in DirAccess.get_directories_at(dir):
		var path: String = dir.path_join(sub)
		if not sub.begins_with(".") and not Files.IGNORED.has(path):
			_check_name(path, "directory")
			_check_directory(path)


static func _check_name(path: String, kind: String) -> void:
	var name: String = path.get_file().get_slice(".", 0)
	if RegEx.create_from_string(SNAKE_CASE).search(name):
		return
	if DOCUMENTS.has(path.get_extension()) and RegEx.create_from_string(DOCUMENT_CASE).search(name):
		return
	
	UnitTester.fail(path, 0, "%s name %s should be snake_case" % [kind, path.get_file()])
