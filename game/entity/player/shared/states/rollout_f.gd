@tool
extends State

@export var rollout_jump_strength: float = 200
@export var rollout_x_speed_cap: float = 625

func _on_enter() -> void:
	player.velocity.x = clamp(player.velocity.x, -rollout_x_speed_cap, rollout_x_speed_cap)
	player.velocity.y = -rollout_jump_strength
	player.can_dive = false
	await pause(0.275)
	player.can_dive = true


func _on_exit() -> void:
	player.can_dive = true
