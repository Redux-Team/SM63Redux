extends LevelObject

@export var break_sfx: AudioStreamPlayer2D
@export var textures: Array[Texture2D]
@export var break_sfx_list: Array[AudioStream]
@export var debris: AnimatedParticles
@export var sprite: SmartSprite2D
@export var collision_shape: CollisionShape2D
@export var hurt_box: HurtBox
@export var coin: PackedScene

## Kept alive after breaking so the debris and the break sound finish rather than being cut off.
@export var cleanup_delay: float = 2.0

var coin_amount: int = 5


func _ready() -> void:
	sprite.texture = textures.pick_random()


func destroy() -> void:
	sprite.hide()
	break_sfx.stream = break_sfx_list.pick_random()
	break_sfx.play()
	collision_shape.set_deferred(&"disabled", true)
	hurt_box.disable()
	debris.burst()
	Singleton.instantiate_sibling(self, coin, coin_amount, 12, ["position"])
	get_tree().create_timer(cleanup_delay).timeout.connect(queue_free)


func _on_hurt_box_damaged(_source_hitbox: HitBox) -> void:
	destroy()
