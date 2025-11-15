extends State

func _on_enter(_from: StringName) -> void:
	player.has_gravity = true
	player.can_jump = false


func _on_exit(_to: StringName) -> void:
	player.can_jump = true
