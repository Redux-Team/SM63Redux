class_name TestDraggable
extends Panel

signal moved

var pressed: bool = false:
	set(p):
		pressed = p


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			pressed = event.pressed
	
	if event is InputEventMouseMotion and pressed:
		position += event.relative
		moved.emit()
