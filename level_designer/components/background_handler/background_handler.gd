class_name LDBackgroundHandler
extends LDComponent

const HILLS_BG = preload("uid://st4r6o6hqwhj")


func _on_ready() -> void:
	LD.get_editor_viewport().set_background(HILLS_BG.instantiate())
