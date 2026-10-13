class_name JumpState
extends PlayerState

@export_group("Launch")
## Upward speed set on takeoff.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var strength: float = 332.5
## Horizontal speed in the facing direction needed to chain into this jump; zero always allows it.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var required_speed: float = 0.0
@export_group("Release")
## Multiplier on upward speed when jump is released early.
@export_range(0.0, 1.0) var cut_multiplier: float = 0.75
@export_group("Chain")
## Time on the ground after landing during which the next jump in the chain is available.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var chain_window: float = 0.15
@export_group("Spin")
## Allows a spin to interrupt this jump.
@export var can_spin: bool = true
## Downward speed that must be reached before a spin can interrupt the jump.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var spin_min_speed: float = -55.0


func can_chain() -> bool:
	return required_speed <= 0.0 or absf(player.velocity.x) >= required_speed and player.is_moving_with_facing()


func _next() -> StringName:
	return &"Spin" if can_spin and controls.is_held(&"spin") and player.velocity.y > spin_min_speed else &""
