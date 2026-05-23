extends LevelObject

@export var spawn: PackedScene
@export var sprite: SmartSprite2D
@export var open_sfx: AudioStreamPlayer2D
@export var player_area_check: Area2D


func _on_hurt_box_damaged(source_hitbox: HitBox) -> void:
	if source_hitbox.owner is Player and source_hitbox.owner.velocity.y > 0:
		var player: Player = source_hitbox.owner
		player.velocity.y = -200
		open_sfx.play()
		player_area_check.set_deferred(&"monitoring", false)
		sprite.play(&"open")
		
		var object: Node2D = spawn.instantiate()
		get_parent().add_child(object)
		get_parent().move_child(object, get_index())
		object.position = position
		
		await sprite.animation_finished
		
		queue_free()
