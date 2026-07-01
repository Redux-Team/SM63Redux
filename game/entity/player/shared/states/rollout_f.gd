@tool
extends State

@export var rollout_jump_strength: float = 200
@export var rollout_x_terminal_velocity: float = 625
## Time after entering rollout state (in seconds), after which the player can dive again.
@export var dive_cooldown: float = 0.275

func _on_enter() -> void:
	player.velocity.x = clamp(player.velocity.x, -rollout_x_terminal_velocity, rollout_x_terminal_velocity)
	player.velocity.y = -rollout_jump_strength
	player.can_dive = false
	await pause(dive_cooldown)
	player.can_dive = true


func _on_exit() -> void:
	player.can_dive = true
