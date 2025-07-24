extends State


func _on_enter(_from: StringName) -> void:
	player.is_running = true


func _on_exit(to: StringName) -> void:
	if to != &"run_loop":
		player.is_running = false
