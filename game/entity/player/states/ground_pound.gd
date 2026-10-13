extends PlayerState

## Hitbox active for the whole ground pound.
@export var hitbox: HitBox


func _enter() -> void:
	hitbox.enable()


func _exit() -> void:
	hitbox.disable()


func _next() -> StringName:
	return &"GroundPoundStart" if is_current() else &""
