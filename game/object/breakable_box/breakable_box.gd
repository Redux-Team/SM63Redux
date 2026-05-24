extends LevelObject

@export var break_sfx: AudioStreamPlayer2D
@export var textures: Array[Texture2D]
@export var break_sfx_list: Array[AudioStream]
@export var particle_emitter: ParticleEmitter
@export var sprite: SmartSprite2D
@export var collision_shape_2d: CollisionShape2D
@export var hurt_box: HurtBox
@export var coin: PackedScene

var coin_amount: int = 5


func _ready() -> void:
	sprite.texture = textures.pick_random()


func destroy() -> void:
	sprite.hide()
	break_sfx.stream = break_sfx_list.pick_random()
	break_sfx.play()
	collision_shape_2d.set_deferred(&"disabled", true)
	hurt_box.disable()
	particle_emitter.emitting = true
	Singleton.instantiate_sibling(self, coin, coin_amount, 12, ["position"])


func _on_particle_emitter_finished() -> void:
	queue_free()


func _on_hurt_box_damaged(source_hitbox: HitBox) -> void:
	if source_hitbox.owner is Player:
		var player: Player = source_hitbox.owner as Player
		if player.state_machine.get_current_state().get_internal_name().begins_with("ground_pound"):
			player.velocity.y /= 2
	destroy()
