extends State

@export var animation_player: AnimationPlayer

func _on_enter(_from: StringName) -> void:
	player.velocity.y = -player.triple_jump_strength
	player.current_jump = 0
