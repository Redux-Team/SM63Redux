class_name Coin
extends Entity

const EXPLODE_SPREAD: float = 15.0
const EXPLODE_STRENGTH: float = 200.0

@export var particle_emitter: ParticleEmitter
@export var sfx_player: AudioStreamPlayer2D
@export var entity_check_area: EntityCheckArea
@export var gravity_component: GravityComponent
@export var explode_on_spawn: bool


func _on_init() -> void:
	scale = Vector2.ONE
	sprite.play(&"default")
	if explode_on_spawn:
		explode(randf_range(-EXPLODE_SPREAD, EXPLODE_SPREAD), EXPLODE_STRENGTH)


func explode(strength_x: float = 0.0, strength_y: float = 0.0) -> void:
	velocity = Vector2(strength_x * randf_range(0.5, 6.0), -strength_y * randf_range(0.5, 1.5)) / (10.0 if is_in_water() else 1.0)
	gravity_component.enabled = true


func reward(player: Player, coins: int, power: int, fludd_power: float) -> void:
	var level: Level = Level.of(self)
	if level:
		level.collect_coin(&"yellow", coins)
	(player.get_component(HealthComponent) as HealthComponent).power += power
	player.fludd.power += fludd_power


func _spawn_collect_particles() -> void:
	var emitter: ParticleEmitter = particle_emitter.duplicate()
	emitter.emitting = true
	Spawner.spawn_near(self, emitter)


func _hide_and_disable() -> void:
	sprite.hide()
	entity_check_area.disable()
