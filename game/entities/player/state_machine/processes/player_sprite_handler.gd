extends StateProcess


func _physics_process(_delta: float) -> void:
	if player.move_dir != 0 and not player.lock_flipping:
		sprite.flip_h = player.move_dir < 0
