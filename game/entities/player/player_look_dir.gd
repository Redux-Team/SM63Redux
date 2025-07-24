extends StateProcess


func _process(_delta: float) -> void:
	if sign(player.move_dir) == sign(player.velocity.x) and abs(player.move_dir) > 0:
		sprite.flip_h = sign(player.move_dir) < 0
