extends BobombState


const MIN_TIME: float = 0.1

@export var fuse: SmartSprite2D
@export var key: SmartSprite2D
@export var hurtbox_shape: CollisionShape2D


func _enter() -> void:
	fuse.hide()
	key.hide()
	hurtbox_shape.set_deferred(&"disabled", true)


func _next() -> StringName:
	if time > MIN_TIME and (bobomb.is_on_floor() or bobomb.is_on_wall()):
		return &"Kaboom"
	return &""
