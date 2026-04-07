extends State


func _on_enter(_from: StringName) -> void:
	state_machine.set_condition(&"landed", true)


func _on_exit(_to: StringName) -> void:
	state_machine.set_condition(&"landed", false)
