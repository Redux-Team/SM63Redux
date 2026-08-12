extends Control

## Splash shown while the two heavy startup resources load. The object database and the editor
## scene together account for most of a cold open, and loading them on background threads overlaps
## them with each other instead of paying for both in a single blocking frame.


const EDITOR_SCENE: String = "uid://cf4yw3eqr2qo6"
const OBJECT_DB: String = "uid://860ancqo5p43"


func _ready() -> void:
	for path: String in [OBJECT_DB, EDITOR_SCENE]:
		ResourceLoader.load_threaded_request(path)

	while true:
		var pending: bool = false
		for path: String in [OBJECT_DB, EDITOR_SCENE]:
			if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				pending = true
		if not pending:
			break
		await get_tree().process_frame

	# Hand the database to its cache now, so the first get_db() during the editor's _ready is free.
	GameDB.get_db()
	get_tree().change_scene_to_file(EDITOR_SCENE)
