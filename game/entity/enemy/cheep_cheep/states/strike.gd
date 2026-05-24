@tool
extends State

@export var friction_component: FrictionComponent
var t: Tween


func _on_enter() -> void:
	friction_component.enabled = true
	t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(sprite, "rotation_degrees", 270.0, 1.0)


func _on_physics_tick(_delta: float) -> void:
	if entity.is_in_water():
		entity.velocity = lerp(entity.velocity, Vector2.ZERO, 0.08)
		if entity.get_active_state_uptime() > 0.6:
			entity.queue_free()
	else:
		if entity.get_active_state_uptime() > 0.6 and entity.is_on_floor():
			entity.queue_free()
