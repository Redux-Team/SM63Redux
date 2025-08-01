extends StateProcess


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"jump"):
		player.current_jump += 1
		state_machine.set_state(&"jump")
