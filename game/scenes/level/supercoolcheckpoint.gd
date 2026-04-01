class_name SuperCoolCheckpoint
extends Node2D

@export var id: int = 1


func _ready() -> void:
	if Singleton.has_meta("checkpoint") and Singleton.get_meta("checkpoint") == id:
		activate()

func activate() -> void:
	$Sprite2D.hide()
	$Sprite2D2.show()
