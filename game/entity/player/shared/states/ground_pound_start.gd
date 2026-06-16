@tool
extends State

@export var ground_pound_start_velocity: Vector2 = Vector2(0, -38)

func _on_enter() -> void:
	player.velocity = ground_pound_start_velocity
	player.current_jump = 0


func _on_physics_tick(_delta: float) -> void:
	player.velocity.y = ground_pound_start_velocity.y
