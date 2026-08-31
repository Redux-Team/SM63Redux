class_name Goomba
extends Entity

@export var player_check: Area2D

var target: Player
var squished_by: Player


func _on_area_2d_area_entered(area: Area2D) -> void:
	if not area.has_meta("player") or machine.get_state_name() in [&"Squish", &"Strike"]:
		return
	
	var player: Player = area.owner
	sprite.flip_h = player.global_position.x < global_position.x
	target = player
	machine.change_state(&"Alert")
	player_check.set_deferred("monitoring", false)


func _on_hurt_box_damaged(source_hitbox: HitBox) -> void:
	if source_hitbox.damage_type == HitBox.DamageType.SQUISH:
		squished_by = source_hitbox.owner
		machine.change_state(&"Squish")
