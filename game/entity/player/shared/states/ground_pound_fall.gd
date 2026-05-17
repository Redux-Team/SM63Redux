@tool
extends State


func _on_enter() -> void:
	player.velocity.y = 800


func _on_physics_tick(_delta: float) -> void:
	if player.velocity.y <= 50 and player.is_in_water:
		print("a")
		state_machine.change_state("swim_idle")
	if player.is_in_water:
		player.velocity.y = lerpf(player.velocity.y, 0, 0.08)
	
	player.velocity.y = min(player.velocity.y, 800)
