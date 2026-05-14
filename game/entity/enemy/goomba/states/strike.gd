@tool
extends State

@export var hit_box: HitBox


func _on_enter() -> void:
	sprite.play("strike")
	hit_box.set_deferred("monitorable", false)
	hit_box.set_deferred("monitoring", false)


func _on_physics_tick(_delta: float) -> void:
	if entity.is_on_floor() and get_elapsed_time() > 0.1:
		sprite.play("squish")
		await sprite.animation_finished
		entity.queue_free()
