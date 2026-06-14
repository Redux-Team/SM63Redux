class_name LevelRuntime
extends Node2D

## Plays a level from the dict handed over in the "playtest" Singleton meta (set by the
## level designer before switching scenes). Returns to the editor via the back button.

const LEVEL_DESIGNER_SCENE: String = "uid://cf4yw3eqr2qo6"

@export var level_root: Node2D


var _level: Level


func _ready() -> void:
	_level = Level.instantiate()
	_level.name = "Level"
	level_root.add_child(_level)
	_level.load_from_dict(Singleton.get_meta("playtest"))
	Singleton.get_level_clock().start()


func _on_back_button_pressed() -> void:
	Singleton.get_level_clock().stop()
	_reset_audio_effects()
	get_tree().change_scene_to_file(LEVEL_DESIGNER_SCENE)


## Strips any runtime-added master-bus effects (e.g. underwater filtering) so they don't
## carry over into the editor after returning.
func _reset_audio_effects() -> void:
	while AudioServer.get_bus_effect_count(0) > 0:
		AudioServer.remove_bus_effect(0, 0)
