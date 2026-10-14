extends GoonieState


@export var duration: float = 6.5


func _tick(_delta: float) -> void:
	goonie.velocity.x = goonie.speed * cos(deg_to_rad(goonie.flap_angle))
	goonie.velocity.y = -goonie.speed * sin(deg_to_rad(goonie.flap_angle))


func _next() -> StringName:
	if time >= duration:
		return &"Glide"
	if goonie.has_rider():
		return &"HeavyFlap"
	return &""
