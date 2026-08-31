extends PlayerState


func _next() -> StringName:
	if player.is_crouching:
		return &"Crouch"
	if not sprite.playing:
		return &"Idle"
	return &""
