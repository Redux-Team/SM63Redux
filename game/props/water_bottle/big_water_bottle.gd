extends Prop

@export var pickup_sfx: AudioStream
@export var water_amount: int = 50
@export var particle_emitter: ParticleEmitter
@export var smart_sprite_2d: SmartSprite2D
@export var entity_check_area: EntityCheckArea


func _on_entity_check_area_player_entered(player: Player) -> void:
	_disable()
	
	SFX.build(pickup_sfx).set_db(-5).play()
	player.fludd.fuel = minf(player.fludd.fuel + water_amount, PlayerFludd.FUEL_MAX)
	
	particle_emitter.emitting = true
	await particle_emitter.finished
	queue_free()


func _disable() -> void:
	smart_sprite_2d.hide()
	entity_check_area.disable()
