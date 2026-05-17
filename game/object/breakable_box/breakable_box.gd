extends LevelObject

@export var break_sfx: AudioStreamPlayer2D
@export var particle_emitter: ParticleEmitter
@export var sprite: SmartSprite2D
@export var collision_shape_2d: CollisionShape2D
@export var hurt_box: HurtBox


func destroy() -> void:
	sprite.hide()
	break_sfx.play()
	collision_shape_2d.set_deferred(&"disabled", true)
	hurt_box.disable()
	particle_emitter.emitting = true


func _on_particle_emitter_finished() -> void:
	queue_free()


func _on_hurt_box_damaged(source_hitbox: HitBox) -> void:
	if source_hitbox.owner is Player:
		var player: Player = source_hitbox.owner as Player
		if player.state_machine.get_current_state().get_internal_name().begins_with("ground_pound"):
			player.velocity.y /= 2
	destroy()
