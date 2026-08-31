extends CheepCheepState


func _next() -> StringName:
	return &"Flop" if not cheep_cheep.is_in_water() else &""
