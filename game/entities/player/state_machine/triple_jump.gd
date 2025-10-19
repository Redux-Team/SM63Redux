extends State

@export var animation_player: AnimationPlayer

func _on_enter(_from: StringName) -> void:
	if player.sprite.flip_h:
		animation_player.play(&"triple_jump_r")
	player.lock_flipping = true
	player.velocity.y = -player.triple_jump_strength
	player.current_jump = 0
	

func set_initial_rotation() -> void:
	if player.sprite.flip_h:
		player.sprite.rotation_degrees = 1440
	else:
		player.sprite.rotation_degrees = 0


func _on_exit(_to: StringName) -> void:
	player.lock_flipping = false
