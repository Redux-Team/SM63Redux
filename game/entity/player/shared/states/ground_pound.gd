extends PlayerState


@export var ground_pound_hitbox: HitBox


func _enter() -> void:
	ground_pound_hitbox.enable()


func _exit() -> void:
	ground_pound_hitbox.disable()


func _next() -> StringName:
	return &"GroundPoundStart" if is_current() else &""
