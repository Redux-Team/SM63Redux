class_name Koopa
extends Entity

@export var shell: PackedScene
@export var audio_stream_player_2d: AudioStreamPlayer2D


func _on_hurt_box_damaged(source_hitbox: HitBox) -> void:
	var koopa_shell: KoopaShell = shell.instantiate()
	Singleton.spawn_sibling(self, koopa_shell, ["position", "scale"])
	koopa_shell.position.y += 8
	
	if source_hitbox.damage_type == HitBox.DamageType.STRIKE:
		koopa_shell.velocity = self.velocity
	
	if source_hitbox.damage_type == HitBox.DamageType.SQUISH and source_hitbox.owner is Player and not source_hitbox.owner.is_on_floor():
		source_hitbox.owner.velocity.y = -200
	
	koopa_shell.audio_stream_player_2d.play.call_deferred()
	
	queue_free()
