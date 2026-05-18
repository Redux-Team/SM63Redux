class_name Parakoopa
extends Entity

@export var koopa: PackedScene
@export var shell: PackedScene
@export var particle_emitter: ParticleEmitter
@export var wing_2: Texture2D

var wing_emitter_1: ParticleEmitter
var wing_emitter_2: ParticleEmitter


func _ready() -> void:
	super()
	
	wing_emitter_1 = _spawn_wing_particle()
	wing_emitter_2 = _spawn_wing_particle()
	
	wing_emitter_2.direction = Vector2.LEFT
	wing_emitter_2.texture = wing_2
	
	particle_emitter.queue_free()


func _on_hurt_box_damaged(source_hitbox: HitBox) -> void:
	if source_hitbox.damage_type == HitBox.DamageType.STRIKE:
		var shell_node: KoopaShell = shell.instantiate()
		Singleton.spawn_sibling(self, shell_node, ["position", "scale"])
		
		shell_node.velocity = velocity
		shell_node.audio_stream_player_2d.play()
	
	if source_hitbox.damage_type == HitBox.DamageType.SQUISH and source_hitbox.owner is Player and not source_hitbox.owner.is_on_floor():
		var koopa_node: Koopa = koopa.instantiate()
		Singleton.spawn_sibling(self, koopa_node, ["position", "scale"])
		
		source_hitbox.owner.velocity.y = -200
		koopa_node.audio_stream_player_2d.play()
	
	Singleton.spawn_sibling(self, wing_emitter_1, ["position", "scale"])
	Singleton.spawn_sibling(self, wing_emitter_2, ["position", "scale"])
	
	wing_emitter_1.emitting = true
	wing_emitter_2.emitting = true
	
	queue_free()


func _spawn_wing_particle() -> ParticleEmitter:
	var emitter: ParticleEmitter = particle_emitter.duplicate()
	emitter.emitting = true
	
	return emitter
