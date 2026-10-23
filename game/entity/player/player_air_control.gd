class_name PlayerAirControl
extends Resource

@export_group("Steering")
## Horizontal speed that steering accelerates toward.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var max_speed: float = 190.0
## Steering acceleration toward the input direction.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s^2")
var acceleration: float = 765.0
## Steering acceleration while reversing direction above the turn speed
## threshold.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s^2")
var turn_acceleration: float = 2520.0
## Minimum opposing speed before turn acceleration is used.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s")
var turn_speed_threshold: float = 10.0
@export_group("Momentum")
## Speed that momentum carries toward while holding forward above max speed.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s")
var momentum_max_speed: float = 400.0
## Acceleration toward momentum max speed while holding forward above max speed.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s^2")
var momentum_acceleration: float = 30.0
@export_group("Drag")
## Deceleration toward zero while there is no horizontal input.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s^2") var drag: float = 120.0
## Deceleration toward zero without input while faster than max speed.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s^2")
var over_speed_drag: float = 300.0
