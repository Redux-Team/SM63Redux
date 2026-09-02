extends LevelObject

@export var sprite: SmartSprite2D
@export var sfx_player: AudioStreamPlayer2D
@export var particle_emitter: CPUParticles2D

var _collected: bool = false


func _ready() -> void:
	sprite.play(&"spin")


func _on_area_2d_body_entered(colliding_body: Node2D) -> void:
	if _collected or not colliding_body is Player:
		return
	_collected = true

	sprite.hide()
	sfx_player.stop()
	particle_emitter.emitting = false

	var level: Level = Level.get_instance()
	if not level:
		return
	# Record the shine in the level's progress, then leave the level if this shine kicks the
	# player out (the default).
	level.collect_shine(int(get_property(&"scenario_id", 0)))
	if bool(get_property(&"kickout", true)):
		level.request_kickout()
