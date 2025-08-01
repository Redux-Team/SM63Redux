extends State


func _on_enter(_from: StringName) -> void:
	player.velocity.y = -player.jump_strength
