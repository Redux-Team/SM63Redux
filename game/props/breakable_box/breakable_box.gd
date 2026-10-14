extends Prop

const COIN_SPREAD: float = 12.0

@export var break_sfx: AudioStreamPlayer2D
@export var textures: Array[Texture2D]
@export var break_sfx_list: Array[AudioStream]
@export var debris: AnimatedParticles
@export var sprite: SmartSprite2D
@export var collision_shape: CollisionShape2D
@export var hurt_box: HurtBox
@export var coin: PackedScene
@export var cleanup_delay: float = 2.0
@export var default_coin_amount: int = 5


func _on_init() -> void:
	if not textures.is_empty():
		sprite.texture = textures.pick_random()


func destroy() -> void:
	sprite.hide()
	break_sfx.stream = break_sfx_list.pick_random()
	break_sfx.play()
	collision_shape.set_deferred(&"disabled", true)
	hurt_box.disable()
	debris.burst()
	Spawner.spawn_burst(self, coin, get_property(&"coin_amount", default_coin_amount), COIN_SPREAD)
	get_tree().create_timer(cleanup_delay).timeout.connect(queue_free)


func _on_hurt_box_damaged(_source_hitbox: HitBox) -> void:
	destroy()
