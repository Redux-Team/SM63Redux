extends State

func _on_enter(_from: StringName) -> void:
	player.velocity.y = 800


func _on_exit(_to: StringName) -> void:
	player.has_gravity = true
