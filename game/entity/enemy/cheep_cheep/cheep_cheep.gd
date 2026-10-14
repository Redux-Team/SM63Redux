class_name CheepCheep
extends Entity

@export var water_vision_area: EntityCheckArea
@export var close_vision_area: EntityCheckArea
@export var lost_vision_area: EntityCheckArea


func is_player_in_vision() -> bool:
	if water_vision_area.is_player_inside() and water_vision_area.get_first_player().is_in_water():
		return true
	return close_vision_area.is_player_inside()


func is_player_out_of_vision() -> bool:
	return not lost_vision_area.is_player_inside()


func _on_water_check_body_water_entered() -> void:
	velocity.y = 0
