extends PlayerState


func _next() -> StringName:
	return &"GroundPoundStart" if is_current() else &""
