extends PlayerState

## Input strength needed to start walking.
@export var walk_input_threshold: float = 0.1
## Speed below which crouch starts a crouch instead of a floorslide.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var crouch_max_speed: float = 50.0
## How long a jump press stays valid after it was pressed.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var jump_buffer: float = 0.2


func _next() -> StringName:
	var grounded: bool = player.is_on_floor()
	var slow: bool = absf(player.velocity.x) <= crouch_max_speed
	if controls.is_held(&"spin"):
		return &"Spin"
	if grounded and slow and controls.is_held(&"crouch"):
		return &"Crouch"
	if grounded and not slow and controls.is_just_pressed(&"crouch"):
		return &"Floorslide"
	if grounded and absf(player.move_input) > walk_input_threshold:
		return &"Walk"
	if not grounded and player.velocity.y >= 0.0:
		return &"Fall"
	if grounded and player.can_jump and controls.is_buffered(&"jump", jump_buffer):
		return &"BaseJump"
	return &""
