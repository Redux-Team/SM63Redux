extends StateProcess

func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"jump"):
		state_machine.set_state(&"jump")
