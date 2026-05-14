@tool
extends State

@export var hit_box: HitBox

var goomba: Goomba:
	get:
		return entity as Goomba
var p: Player
var finished: bool = false


func _on_enter() -> void:
	p = goomba.squished_by
	hit_box.set_deferred("monitoring", false)
	hit_box.set_deferred("monitorable", false)
	sprite.animation_finished.connect(func() -> void:
		owner.queue_free()
	)
	await get_tree().create_timer(0.2).timeout
	finished = true
	if not p.state_machine.get_current_state().get_internal_name().begins_with("ground_pound"):
		p.velocity.y = -280


func _on_physics_tick(_delta: float) -> void:
	if not finished and not p.state_machine.get_current_state().get_internal_name().begins_with("ground_pound"):
		p.velocity.y = 0
