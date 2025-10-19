extends State


func _physics_process(delta: float) -> void:
	if player.is_on_floor():
		player.apply_friction()
