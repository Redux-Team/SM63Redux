class_name SprayProfile
extends Resource

## Speed water leaves the nozzle at.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var speed: float = 280.0
## Share of the player's movement added to the water.
@export_range(0.0, 1.0) var inherit_velocity: float = 0.6
## Acceleration applied to the water.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s²") var gravity: Vector2 = Vector2(0.0, 500.0)
## Time water lasts before disappearing.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var lifetime: float = 0.6
## Furthest the stream reaches along its curve.
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var max_length: float = 128.0
## Stream width at empty power, relative to full power.
@export_range(0.0, 1.0) var empty_width_scale: float = 1.0
