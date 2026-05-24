@tool
extends State


func _on_physics_tick(_delta: float) -> void:
	if entity.is_on_floor():
		entity.velocity.y = -randi_range(130, 180)
		entity.velocity.x = randi_range(-30, 30)
