class_name YellowCoin
extends Entity

@export var particle_emitter: ParticleEmitter
@export var audio_stream_player_2d: AudioStreamPlayer2D
@export var entity_check_area: EntityCheckArea
@export var gravity_component: GravityComponent
@export var bouncy_component: BouncyComponent
@export var explode_on_spawn: bool


func _ready() -> void:
	scale = Vector2.ONE
	sprite.play(&"default")
	if explode_on_spawn:
		explode(randf_range(-15, 15), 200)

## Call this function to make the coin go a random direction
func explode(strength_x: float = 0.0, strength_y: float = 0.0) -> void:
	velocity = Vector2(strength_x, -strength_y) / (10.0 if is_in_water() else 1.0)
	gravity_component.enabled = true


func _on_entity_check_area_player_entered(_player: Player) -> void:
	var emitter: ParticleEmitter = particle_emitter.duplicate()
	
	Singleton.spawn_sibling(self, emitter, ["position", "scale", "rotation"])
	
	emitter.emitting = true
	audio_stream_player_2d.play()
	
	sprite.hide()
	entity_check_area.disable()
	
	await audio_stream_player_2d.finished
	queue_free()
