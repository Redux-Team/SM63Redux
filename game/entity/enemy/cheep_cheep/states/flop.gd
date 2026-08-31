extends CheepCheepState


func _tick(_delta: float) -> void:
	if cheep_cheep.is_on_floor():
		cheep_cheep.velocity.y = -randi_range(130, 180)
		cheep_cheep.velocity.x = randi_range(-30, 30)
