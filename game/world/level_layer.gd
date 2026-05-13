class_name LevelLayer
extends CanvasGroup


var _parallax: Parallax2D


func _init() -> void:
	_parallax = Parallax2D.new()
	add_child(_parallax)
