class_name Goomba
extends Entity

@export var player_check: Area2D

var target: Player
var squished_by: Player


func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.has_meta("player"):
		var player: Player = area.owner
		var relative: int = sign(player.global_position.x - global_position.x)
		sprite.flip_h = false if relative >= 0 else true
		target = player
		state_machine.change_state("alert")
		player_check.set_deferred("monitoring", false)
		


func _on_hurt_box_damaged(source_hitbox: HitBox) -> void:
	var player: Player = source_hitbox.owner
	squished_by = player
	
	state_machine.change_state("squish")
