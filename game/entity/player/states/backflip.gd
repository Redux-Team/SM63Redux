extends PlayerState

@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var backward_speed: float = 280.0
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var rise_speed: float = 392.5
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var spin_min_speed: float = 155.0


func _enter() -> void:
	player.lock_flipping = true
	player.velocity.x -= backward_speed * player.get_facing()
	player.velocity.y = -rise_speed


func _exit() -> void:
	unlock_flipping()


func _next() -> StringName:
	if player.is_on_floor():
		return &"Idle"
	if player.can_dive and controls.is_just_pressed(&"dive"):
		return &"Dive"
	if controls.is_held(&"spin") and player.velocity.y > spin_min_speed:
		return &"Spin"
	return &""


func unlock_flipping() -> void:
	player.lock_flipping = false
