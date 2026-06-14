extends Node2D


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
	var audio_effect_count: int = AudioServer.get_bus_effect_count(0)
	for i: int in audio_effect_count:
		AudioServer.remove_bus_effect(0, 0)
	get_tree().change_scene_to_file("uid://cf4yw3eqr2qo6")
