extends Node2D

@export var level_root: Node2D

func _ready() -> void:
	var level_handler: LevelHandler = LevelHandler.new()
	add_child(level_handler)
	level_handler.setup(level_root)
	if Singleton.has_meta("playtest"):
		level_handler.load_from_dict(Singleton.get_meta("playtest"))
		Singleton.get_level_clock().start()


func _on_back_button_pressed() -> void:
	Singleton.get_level_clock().stop()
	get_tree().change_scene_to_file("uid://cf4yw3eqr2qo6")
