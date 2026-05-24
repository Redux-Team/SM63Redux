@tool
extends State

enum AlertState {
	JUMP,
	FALL,
	LANDED
}

var alert_state: AlertState = AlertState.JUMP


func _on_enter() -> void:
	if entity.is_on_floor():
		if entity.is_in_water():
			entity.local_velocity = Vector2(-30, -50)
		else:
			entity.local_velocity = Vector2(-30, -200)
	else:
		entity.local_velocity = Vector2(-30, 10)
	sprite.play("alert_jump")


func _on_physics_tick(_delta: float) -> void:
	if not entity.is_on_floor() and entity.velocity.y > 0:
		sprite.play("alert_fall")
	if entity.is_on_floor() and get_elapsed_physics_frames() > 5:
		sprite.play("alert_landed")
		await get_tree().create_timer(0.1).timeout
		done()
