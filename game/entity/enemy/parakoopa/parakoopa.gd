class_name Parakoopa
extends Entity

@export var koopa: PackedScene
@export var shell: PackedScene
@export var particle_emitter: ParticleEmitter
@export var wing_2: Texture2D


func _on_hurt_box_damaged(source_hitbox: HitBox) -> void:
	if is_queued_for_deletion():
		return
	
	if source_hitbox.damage_type == HitBox.DamageType.STRIKE:
		var shell_node: KoopaShell = shell.instantiate()
		Singleton.spawn_sibling(self, shell_node, ["position", "scale"])
		
		shell_node.velocity = velocity
		shell_node.audio_stream_player_2d.play()
	
	if source_hitbox.damage_type == HitBox.DamageType.SQUISH and source_hitbox.owner is Player and not source_hitbox.owner.is_on_floor():
		var koopa_node: Koopa = koopa.instantiate()
		Singleton.spawn_sibling(self, koopa_node, ["position", "scale"])
		
		source_hitbox.owner.velocity.y = -200
		koopa_node.audio_stream_player_2d.play.call_deferred()
	
	_spawn_wing_particle()
	
	var wing_emitter_2: ParticleEmitter = _spawn_wing_particle()
	wing_emitter_2.direction = Vector2.LEFT
	wing_emitter_2.texture = wing_2
	
	queue_free()


## Copies the idle in-scene emitter into the level as a one-shot wing puff. Duplicating on death
## rather than in _ready keeps every copy parented, so a parakoopa still alive when the level
## unloads cannot strand them outside the tree.
func _spawn_wing_particle() -> ParticleEmitter:
	var emitter: ParticleEmitter = particle_emitter.duplicate()
	emitter.emitting = true
	Singleton.spawn_sibling(self, emitter, ["position", "scale"])
	
	return emitter
