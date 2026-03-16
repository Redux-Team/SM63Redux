class_name LDViewportInput
extends Control


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	LD.get_input_handler().dispatch(event)
	accept_event()
