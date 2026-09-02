extends LevelObject

const BOUNCE_VELOCITY: float = -200.0

@export var spawn: PackedScene
@export var sprite: SmartSprite2D
@export var open_sfx: AudioStreamPlayer2D

var _opened: bool = false


func _on_hurt_box_damaged(source_hitbox: HitBox) -> void:
	var player: Player = source_hitbox.owner as Player
	if _opened or not player or player.velocity.y <= 0:
		return
	
	_opened = true
	player.velocity.y = BOUNCE_VELOCITY
	open_sfx.play()
	sprite.play(&"open")
	
	Singleton.spawn_sibling(self, spawn.instantiate(), ["position"])
	
	await sprite.animation_finished
	
	queue_free()
