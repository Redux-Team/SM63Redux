extends PlayerState


const DURATION: float = 0.3


func _enter() -> void:
	player.velocity.y = -38
	player.velocity.x = 0
	player.current_jump = 0


func _tick(_delta: float) -> void:
	player.velocity.y = -38


func _next() -> StringName:
	return &"GroundPoundFall" if time >= DURATION else &""
