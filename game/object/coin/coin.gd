class_name Coin
extends Entity

const EXPLODE_SPREAD: float = 15.0
const EXPLODE_STRENGTH: float = 200.0

@export var particle_emitter: ParticleEmitter
@export var sfx_player: AudioStreamPlayer2D
@export var entity_check_area: EntityCheckArea
@export var gravity_component: GravityComponent
@export var explode_on_spawn: bool


func _ready() -> void:
	scale = Vector2.ONE
	sprite.play(&"default")
	if explode_on_spawn:
		explode(randf_range(-EXPLODE_SPREAD, EXPLODE_SPREAD), EXPLODE_STRENGTH)


## Call this function to make the coin go a random direction
func explode(strength_x: float = 0.0, strength_y: float = 0.0) -> void:
	velocity = Vector2(strength_x * randf_range(0.5, 6.0), -strength_y * randf_range(0.5, 1.5)) / (10.0 if is_in_water() else 1.0)
	gravity_component.enabled = true


func _spawn_collect_particles() -> void:
	var emitter: ParticleEmitter = particle_emitter.duplicate()
	Singleton.spawn_sibling(self, emitter, ["position", "scale", "rotation"])
	emitter.emitting = true


func _hide_and_disable() -> void:
	sprite.hide()
	entity_check_area.disable()
