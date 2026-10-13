extends PlayerState

## Input strength needed to start walking along the floor.
@export var walk_input_threshold: float = 0.1
## How long a swim press stays valid for starting a stroke.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var swim_buffer: float = 0.12


func _next() -> StringName:
	if controls.is_held(&"spin"):
		return &"SwimSpin"
	if player.is_swim_pressed(swim_buffer):
		return &"Swim"
	if player.is_on_floor() and absf(player.move_input) > walk_input_threshold:
		return &"SwimWalk"
	return &""
