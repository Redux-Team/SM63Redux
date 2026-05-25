extends LevelObject

@export var spawn: PackedScene
@export var sprite: SmartSprite2D
@export var open_sfx: AudioStreamPlayer2D

var _opened: bool = false


func _on_hurt_box_damaged(source_hitbox: HitBox) -> void:
	if _opened:
		return
	
	if source_hitbox.owner is Player and source_hitbox.owner.velocity.y > 0:
		var player: Player = source_hitbox.owner
		player.velocity.y = -200
		open_sfx.play()
		sprite.play(&"open")
		_opened = true
		
		Singleton.spawn_sibling(self, spawn.instantiate(), ["position"])
		
		await sprite.animation_finished
		
		queue_free()
