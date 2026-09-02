class_name Koopa
extends Entity

const SHELL_DROP_OFFSET: float = 8.0

@export var shell: PackedScene
@export var sfx_player: AudioStreamPlayer2D


func _on_hurt_box_damaged(source_hitbox: HitBox) -> void:
	var koopa_shell: KoopaShell = shell.instantiate()
	Singleton.spawn_sibling(self, koopa_shell, ["position", "scale"])
	koopa_shell.position.y += SHELL_DROP_OFFSET
	
	if source_hitbox.damage_type == HitBox.DamageType.STRIKE:
		koopa_shell.velocity = velocity
	
	source_hitbox.bounce_squisher()
	koopa_shell.sfx_player.play.call_deferred()
	
	queue_free()
