extends State


func _physics_process(delta: float) -> void:
	if (player.velocity.x == 0):
		player.is_running = false 
