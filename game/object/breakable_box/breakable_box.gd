extends LevelObject

@export var break_sfx: AudioStreamPlayer2D
@export var particle_emitter: ParticleEmitter
@export var sprite: SmartSprite2D
@export var collision_shape_2d: CollisionShape2D
@export var static_body_2d: StaticBody2D
@export var spin_check: Area2D
@export var ground_pound_check: Area2D


func destroy() -> void:
	sprite.hide()
	break_sfx.play()
	ground_pound_check.set_deferred(&"monitoring", false)
	spin_check.set_deferred(&"monitoring", false)
	collision_shape_2d.set_deferred(&"disabled", true)
	particle_emitter.emitting = true



func _on_ground_pound_check_body_entered(body: Node2D) -> void:
	if body is Player:
		if body.state_machine.current_state.name in ["GroundPoundFall", "GroundPoundSlam"]:
			body.velocity.y /= 2
			destroy()


func _on_particle_emitter_finished() -> void:
	queue_free()


func _on_spin_check_area_entered(area: Area2D) -> void:
	if area.owner is Player:
		var player: Player = area.owner
		
		if not player.state_machine.current_state.name in ["Spin", "SwimSpin"]:
			return
		
		if player.get_active_state_uptime() <= 0.3:
			destroy()
