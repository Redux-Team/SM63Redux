@tool
extends State


func _on_physics_tick(_delta: float) -> void:
	entity.velocity.y = 10 * sin(get_elapsed_time() * 2)
