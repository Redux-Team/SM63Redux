extends State

func _on_enter(_from: StringName) -> void:
	player.velocity.y = -38
	player.velocity.x = 0
	player.current_jump = 0


func _physics_process(delta: float) -> void:
	player.velocity.y = -38
