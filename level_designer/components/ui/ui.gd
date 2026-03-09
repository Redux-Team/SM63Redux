class_name LDUI
extends CanvasLayer


func _ready() -> void:
	await get_tree().create_timer(2).timeout
	$LDWindow.show()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_SPACE and not $LDWindow.visible:
			$LDWindow.show()
