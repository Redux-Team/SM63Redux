@tool
extends State

@export var entity_check_area_lost: EntityCheckArea


func _on_physics_tick(_delta: float) -> void:
	var p: Player = entity_check_area_lost.get_closest_player(entity.global_position)
	if not p:
		return
	
	var direction: Vector2 = entity.global_position.direction_to(p.global_position)
	entity.velocity = direction * 50.0
	sprite.local_rotation = rad_to_deg(asin(direction.y))


func _on_exit() -> void:
	sprite.rotation = 0
