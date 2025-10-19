extends State


func _on_enter(_from: StringName) -> void:
	if player.sprite.flip_h:
		player.velocity.x = -700
	else:
		player.velocity.x = 700
	
	player.velocity.y = -5
