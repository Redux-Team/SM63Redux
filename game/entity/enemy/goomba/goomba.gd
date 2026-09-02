class_name Goomba
extends Entity


func _on_hurt_box_damaged(source_hitbox: HitBox) -> void:
	if source_hitbox.damage_type == HitBox.DamageType.SQUISH:
		machine.change_state(&"Squish")
