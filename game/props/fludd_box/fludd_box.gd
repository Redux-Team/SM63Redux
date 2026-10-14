extends Prop

const BOUNCE_VELOCITY: float = -200.0

@export var spawn: PackedScene
@export var sprite: SmartSprite2D
@export var open_sfx: AudioStreamPlayer2D
@export var hurt_box: HurtBox

var _opened: bool = false


func _on_hurt_box_damaged(source_hitbox: HitBox) -> void:
	var player: Player = source_hitbox.owner as Player
	if _opened or player == null or player.velocity.y <= 0.0:
		return
	
	_opened = true
	hurt_box.disable()
	player.velocity.y = BOUNCE_VELOCITY
	open_sfx.play()
	sprite.play(&"open")
	Spawner.spawn_near(self, spawn.instantiate(), Vector2.ZERO, true)
	await sprite.animation_finished
	queue_free()
