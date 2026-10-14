extends GoonieState


func _tick(_delta: float) -> void:
	goonie.velocity.x = goonie.speed * cos(deg_to_rad(goonie.heavy_flap_angle))
	goonie.velocity.y = goonie.speed * sin(deg_to_rad(goonie.heavy_flap_angle))


func _next() -> StringName:
	return &"Flap" if not goonie.has_rider() else &""
