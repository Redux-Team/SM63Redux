class_name Goonie
extends Entity


@export var speed: float = 70
@export var flap_angle: float = 17
@export var heavy_flap_angle: float = 40
@export var glide_angle: float = 28
@export var glide_x_boost: float = 1.3

var riders: Dictionary[Variant, bool]


func _ready() -> void:
	velocity.x = speed * cos(deg_to_rad(flap_angle))
	velocity.y = -speed * sin(deg_to_rad(flap_angle))
