extends State


func _on_enter(from: StringName) -> void:
	if from == &"jump":
		state_machine.entity_sprite.frame = 0
		state_machine.entity_sprite.play(&"fall_r_start")
