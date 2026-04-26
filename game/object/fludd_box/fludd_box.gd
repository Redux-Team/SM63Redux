extends LevelObject

@export var spawn: PackedScene
@export var sprite: SmartSprite2D
@export var open_sfx: AudioStreamPlayer2D
@export var player_area_check: Area2D


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Player and body.velocity.y > 0:
		body.velocity.y = -200
		open_sfx.play()
		player_area_check.set_deferred(&"monitoring", false)
		sprite.play(&"open")
		
		var object: Node2D = spawn.instantiate()
		get_parent().add_child(object)
		get_parent().move_child(object, get_index())
		object.position = position
