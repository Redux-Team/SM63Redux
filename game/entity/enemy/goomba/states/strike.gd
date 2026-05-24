@tool
extends State

@export var hit_box: HitBox


func _on_enter() -> void:
	sprite.play("strike")
	hit_box.set_deferred("monitorable", false)
	hit_box.set_deferred("monitoring", false)


func _on_physics_tick(_delta: float) -> void:
	if not entity.is_in_water() and entity.is_on_floor() and get_elapsed_time() > 0.1:
		sprite.play("squish")
		await sprite.animation_finished
		entity.queue_free()
	elif entity.is_in_water():
		if get_elapsed_time() > 1.0:
			entity.queue_free()
		elif entity.is_on_anything() and get_elapsed_time() > 0.1:
			sprite.play("squish")
			await sprite.animation_finished
			entity.queue_free()
