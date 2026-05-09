@tool
extends State

func _on_enter() -> void:
	player.lock_flipping = true
	player.can_jump = false


func _on_exit() -> void:
	player.can_jump = true
