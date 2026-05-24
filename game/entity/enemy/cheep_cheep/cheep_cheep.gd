class_name CheepCheep
extends Entity

@export var entity_check_area_water: EntityCheckArea
@export var entity_check_area_close: EntityCheckArea
@export var entity_check_area_lost: EntityCheckArea


func is_player_in_vision() -> bool:
	if entity_check_area_water.is_player_inside():
		if entity_check_area_water.get_first_player().is_in_water():
			return true
	return entity_check_area_close.is_player_inside()


func is_player_out_of_vision() -> bool:
	return not entity_check_area_lost.is_player_inside()


func get_closest_player() -> Player:
	var area: EntityCheckArea = entity_check_area_water if entity_check_area_water.is_player_inside() else entity_check_area_close
	return area.get_closest_player(global_position)


func _on_water_check_body_water_entered() -> void:
	velocity.y = 0
