extends Node2D


func _ready() -> void:
	Singleton.debug_mode = true
	Singleton.show_touch_screen_layer()
