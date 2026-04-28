extends State


func _on_enter(_from: StringName) -> void:
	print("a")
	player.set_process_input(false)


func _on_exit(_to: StringName) -> void:
	print("b")
	player.set_process_input(true)
