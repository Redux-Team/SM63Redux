extends Control

## Splash shown while the level designer loads. It is by far the heaviest thing in a cold open, so
## it is requested on a background thread rather than paid for in a single blocking frame.


const START_SCENE: String = "uid://cf4yw3eqr2qo6"


func _ready() -> void:
	ResourceLoader.load_threaded_request(START_SCENE)
	
	while ResourceLoader.load_threaded_get_status(START_SCENE) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	
	get_tree().change_scene_to_file(START_SCENE)
