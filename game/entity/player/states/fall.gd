extends PlayerState

## Downward speed that must be reached before a spin can start.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var spin_min_speed: float = 100.0


func _enter() -> void:
	var previous: State = machine.get_last_state()
	if not previous:
		return
	
	if previous.name in [&"DoubleJump", &"TripleJump"]:
		sprite.play(&"double_jump_fall")
	elif previous.name == &"Spin" or not _is_airborne(previous):
		sprite.play(&"fall_loop")


func _next() -> StringName:
	if player.is_on_floor():
		return &"Idle"
	if controls.is_held(&"spin") and player.velocity.y > spin_min_speed:
		return &"Spin"
	if player.can_dive and controls.is_just_pressed(&"dive"):
		return &"Dive"
	return &""


func _is_airborne(state: State) -> bool:
	var node: Node = state
	while node is State:
		if node.name == &"Airborne":
			return true
		node = node.get_parent()
	
	return false
