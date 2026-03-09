class_name LDUI
extends CanvasLayer

@export var ld_window: LDWindow

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_SPACE and event.pressed:
			if ld_window.visible:
				ld_window.popout()
			else:
				ld_window.popin()
