const Files: GDScript = preload("res://dev/unit_tests/project/_files.gd")
const UID_SOURCES: PackedStringArray = ["gd", "gdshader"]
const TEXT_FILES: PackedStringArray = [
	"gd",
	"gdshader",
	"tscn",
	"tres",
	"godot",
	"tgdss",
]


static func run_test() -> void:
	for path: String in Files.find(UID_SOURCES):
		if not FileAccess.file_exists(path + ".uid"):
			UnitTester.fail(path, 0, "Missing .uid file")
		elif ResourceLoader.get_resource_uid(path) == ResourceUID.INVALID_ID:
			UnitTester.fail(path, 0, "Unregistered uid")
	
	for path: String in Files.find(["uid"]):
		if not FileAccess.file_exists(path.trim_suffix(".uid")):
			UnitTester.fail(path, 0, "Orphan .uid file")
	
	for path: String in Files.find(TEXT_FILES):
		if (
				path != ("res://dev/unit_tests/project/" + "uids_and_paths_are_valid.gd")
				and "res://_local/" in Files.read(path)
		):
			UnitTester.fail(path, 0, "Reference to res://_local/")
	
	var uids: Dictionary[int, String] = {}
	for path: String in Files.find(UID_SOURCES + PackedStringArray(["tscn", "tres"])):
		var uid: int = ResourceLoader.get_resource_uid(path)
		if uid != ResourceUID.INVALID_ID and uids.has(uid):
			UnitTester.fail(
					path,
					0,
					"Duplicate uid %s, also used by %s" % [
						ResourceUID.id_to_text(uid),
						uids[uid],
					],
			)
		uids[uid] = path
