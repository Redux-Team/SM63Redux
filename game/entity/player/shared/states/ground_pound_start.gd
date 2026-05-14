@tool
extends State

func _on_enter() -> void:
	player.velocity.y = -38
	player.velocity.x = 0
	player.current_jump = 0


func _on_physics_tick(_delta: float) -> void:
	player.velocity.y = -38
