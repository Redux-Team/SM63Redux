class_name Goomba
extends Entity

var squished_by: Player


func _on_hurt_box_damaged(source_hitbox: HitBox) -> void:
	if source_hitbox.damage_type == HitBox.DamageType.SQUISH:
		squished_by = source_hitbox.owner
		machine.change_state(&"Squish")
