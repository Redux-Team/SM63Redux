@tool
extends State

@export var explosion_shape: CollisionShape2D
@export var explosion: AnimatedSprite2D


func _on_enter() -> void:
	sprite.hide()
	explosion.show()
	explosion.play()
	entity.disable()
	explosion_shape.set_deferred(&"disabled", false)
	await get_tree().process_frame
	await get_tree().process_frame
	explosion_shape.set_deferred(&"disabled", true)
	await get_tree().create_timer(1).timeout
	owner.queue_free()
