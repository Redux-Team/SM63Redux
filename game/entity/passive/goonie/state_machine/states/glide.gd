extends GoonieState


@export var duration: float = 1.5


func _tick(_delta: float) -> void:
	goonie.velocity.x = goonie.speed * goonie.glide_x_boost * cos(deg_to_rad(goonie.glide_angle))
	goonie.velocity.y = goonie.speed * sin(deg_to_rad(goonie.glide_angle))


func _next() -> StringName:
	if goonie.has_rider():
		return &"HeavyFlap"
	if time >= duration:
		return &"Flap"
	return &""
