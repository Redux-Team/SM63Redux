class_name SprayProfile
extends Resource

@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var speed: float = 280.0
@export_range(0.0, 1.0) var inherit_velocity: float = 0.6
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s²") var gravity: Vector2 = Vector2(0.0, 500.0)
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var lifetime: float = 0.6
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var max_length: float = 128.0
@export_range(0.0, 1.0) var empty_width_scale: float = 1.0
