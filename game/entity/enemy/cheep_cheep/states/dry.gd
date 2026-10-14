extends CheepCheepState


func _next() -> StringName:
	return &"Swim" if cheep_cheep.is_in_water() else &""
