extends Control

## Splash shown while the editor scene loads. It is by far the heaviest thing in a cold open, so
## it is requested on a background thread rather than paid for in a single blocking frame.


const EDITOR_SCENE: String = "uid://cf4yw3eqr2qo6"


func _ready() -> void:
	ResourceLoader.load_threaded_request(EDITOR_SCENE)
	
	while ResourceLoader.load_threaded_get_status(EDITOR_SCENE) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	
	get_tree().change_scene_to_file(EDITOR_SCENE)
