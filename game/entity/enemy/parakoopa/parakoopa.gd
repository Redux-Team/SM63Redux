class_name Parakoopa
extends Entity

@export var koopa: PackedScene
@export var shell: PackedScene
@export var particle_emitter: ParticleEmitter
@export var back_wing_texture: Texture2D


func _on_hurt_box_damaged(source_hitbox: HitBox) -> void:
	if is_queued_for_deletion():
		return
	
	if source_hitbox.damage_type == HitBox.DamageType.STRIKE:
		var shell_instance: KoopaShell = shell.instantiate()
		Singleton.spawn_sibling(self, shell_instance, ["position", "scale"])
		
		shell_instance.velocity = velocity
		shell_instance.sfx_player.play()
	
	if source_hitbox.is_airborne_squish():
		var koopa_instance: Koopa = koopa.instantiate()
		Singleton.spawn_sibling(self, koopa_instance, ["position", "scale"])
		
		koopa_instance.sfx_player.play.call_deferred()
	
	source_hitbox.bounce_squisher()
	
	_spawn_wing_particle()
	var back_wing: ParticleEmitter = _spawn_wing_particle()
	back_wing.direction = Vector2.LEFT
	back_wing.texture = back_wing_texture
	
	queue_free()


## Copies the idle in-scene emitter into the level as a one-shot wing puff. Duplicating on death
## rather than in _ready keeps every copy parented, so a parakoopa still alive when the level
## unloads cannot strand them outside the tree.
func _spawn_wing_particle() -> ParticleEmitter:
	var emitter: ParticleEmitter = particle_emitter.duplicate()
	emitter.emitting = true
	Singleton.spawn_sibling(self, emitter, ["position", "scale"])
	
	return emitter
