extends PlayerState


var _cut_applied: bool = false


func _enter() -> void:
	_cut_applied = false


func _tick(_delta: float) -> void:
	if _cut_applied or player.velocity.y >= 0.0 or player.is_action_pressed("jump"):
		return
	
	_cut_applied = true
	player.velocity.y *= player.jump_cut_multiplier


func _next() -> StringName:
	return &"Spin" if player.is_input_spin and player.velocity.y > player.jump_spin_min_speed else &""
