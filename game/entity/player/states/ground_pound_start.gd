extends PlayerState

@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var rise_speed: float = 23.0
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var duration: float = 0.3


func _enter() -> void:
	player.velocity.x = 0.0
	player.jump_chain = 0


func _tick(_delta: float) -> void:
	player.velocity.y = -rise_speed


func _next() -> StringName:
	return &"GroundPoundFall" if time >= duration else &""
