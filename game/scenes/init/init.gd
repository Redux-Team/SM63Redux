extends Control


func _ready() -> void:
	get_tree().change_scene_to_file.call_deferred("res://game/scenes/title_screen/title_screen.tscn")
