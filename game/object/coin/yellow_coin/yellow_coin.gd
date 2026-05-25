class_name YellowCoin
extends Entity

@export var coin_amount: int = 1
@export var power_amount: int = 1
@export var purple: bool = false
@export var purple_group: String = "default"
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
	if purple:
		Level.get_instance().add_purple_coin_max(purple_group)

## Call this function to make the coin go a random direction
func explode(strength_x: float = 0.0, strength_y: float = 0.0) -> void:
	velocity = Vector2(strength_x * randf_range(0.5, 6.0), -strength_y * randf_range(0.5, 1.5)) / (10.0 if is_in_water() else 1.0)
	gravity_component.enabled = true
	collision_mask = 2


func _on_entity_check_area_player_entered(_player: Player) -> void:
	var emitter: ParticleEmitter = particle_emitter.duplicate()
	
	Singleton.spawn_sibling(self, emitter, ["position", "scale", "rotation"])
	
	emitter.emitting = true
	audio_stream_player_2d.play()
	
	if purple:
		Level.get_instance().add_purple_coin(purple_group)
	else:
		Level.get_instance().add_yellow_coin(coin_amount)
		Level.get_player().add_power(power_amount)
	
	sprite.hide()
	entity_check_area.disable()
	
	await audio_stream_player_2d.finished
	queue_free()
