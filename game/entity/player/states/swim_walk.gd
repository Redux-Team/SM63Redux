extends PlayerState

## How long a swim press stays valid for starting a stroke.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var swim_buffer: float = 0.12


func _next() -> StringName:
	if player.is_swim_pressed(swim_buffer):
		return &"Swim"
	if controls.is_held(&"spin"):
		return &"SwimSpin"
	return &""
