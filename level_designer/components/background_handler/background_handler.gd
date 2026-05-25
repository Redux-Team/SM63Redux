class_name LDBackgroundHandler
extends LDComponent


const HILLS_BG = preload("uid://st4r6o6hqwhj")


func _on_ready() -> void:
	var vp: LDViewport = LD.get_editor_viewport()
	LD.get_area().set_background(vp.get_background_root(), HILLS_BG.instantiate())
