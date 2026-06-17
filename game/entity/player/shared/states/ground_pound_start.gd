@tool
extends State

@export var ground_pound_start_velocity: float = 38

func _on_enter() -> void:
	player.velocity.y = -ground_pound_start_velocity
	player.velocity.x = 0
	player.current_jump = 0


func _on_physics_tick(_delta: float) -> void:
	player.velocity.y = -ground_pound_start_velocity
