extends CheepCheepState


const CHASE_SPEED: float = 50.0


func _tick(_delta: float) -> void:
	var player: Player = cheep_cheep.lost_vision_area.get_closest_player(cheep_cheep.global_position)
	if not player:
		return
	
	var direction: Vector2 = cheep_cheep.global_position.direction_to(player.global_position)
	cheep_cheep.velocity = direction * CHASE_SPEED
	sprite.local_rotation = rad_to_deg(asin(direction.y))


func _exit() -> void:
	sprite.rotation = 0


func _next() -> StringName:
	return &"Swim" if cheep_cheep.is_player_out_of_vision() else &""
