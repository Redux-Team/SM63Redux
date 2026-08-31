extends BobombState


const HITBOX_FRAMES: int = 2
const CLEANUP_DELAY: float = 1.0

@export var explosion_shape: CollisionShape2D
@export var explosion: AnimatedSprite2D
@export var hurtbox_shape: CollisionShape2D


func _enter() -> void:
	sprite.hide()
	explosion.show()
	explosion.play()
	bobomb.disable()
	hurtbox_shape.set_deferred(&"disabled", true)
	explosion_shape.set_deferred(&"disabled", false)
	bobomb.spawn_exit_objects()


func _tick(_delta: float) -> void:
	if frames == HITBOX_FRAMES:
		explosion_shape.set_deferred(&"disabled", true)
	elif time >= CLEANUP_DELAY:
		bobomb.queue_free()
