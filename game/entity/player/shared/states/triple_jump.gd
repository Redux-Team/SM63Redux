@tool
extends State

func _on_enter() -> void:
	player.velocity.y = -player.triple_jump_strength
	player.current_jump = 0
