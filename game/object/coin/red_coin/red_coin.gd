class_name RedCoin
extends Entity

@export var group: String = "default"

@export var particle_emitter: ParticleEmitter
@export var audio_stream_player_2d: AudioStreamPlayer2D
@export var entity_check_area: EntityCheckArea
@export var gravity_component: GravityComponent
@export var bouncy_component: BouncyComponent
@export var explode_on_spawn: bool
@export var all_collected: AudioStreamPlayer2D
@export var collect_label: Label

var _collect_tween: Tween

var Max_coin_amount: int = 0:
	get:
		return Level.get_instance().red_coins_max.get(group, 0)
	set(mca):
		Level.get_instance().red_coins_max.set(group, mca)
var Coin_amount: int = 0:
	get:
		return Level.get_instance().red_coins_collected.get(group, 0)
	set(ca):
		Level.get_instance().red_coins_collected.set(group, ca)



func _ready() -> void:
	scale = Vector2.ONE
	sprite.play(&"default")
	if explode_on_spawn:
		explode(randf_range(-15, 15), 200)
	
	Max_coin_amount += 1

## Call this function to make the coin go a random direction
func explode(strength_x: float = 0.0, strength_y: float = 0.0) -> void:
	velocity = Vector2(strength_x * randf_range(0.5, 6.0), -strength_y * randf_range(0.5, 1.5)) / (10.0 if is_in_water() else 1.0)
	gravity_component.enabled = true


func animate_text() -> void:
	collect_label.show()
	collect_label.text = str(Coin_amount)
	
	_collect_tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	_collect_tween.tween_property(collect_label, "self_modulate", Color.WHITE, 0.3)
	_collect_tween.tween_property(collect_label, "position:y", collect_label.position.y - 10, 0.5)


func _on_entity_check_area_player_entered(_player: Player) -> void:
	var emitter: ParticleEmitter = particle_emitter.duplicate()
	
	Singleton.spawn_sibling(self, emitter, ["position", "scale", "rotation"])
	
	emitter.emitting = true
	
	if Coin_amount + 1 == Max_coin_amount:
		all_collected.play()
	else:
		audio_stream_player_2d.pitch_scale = lerpf(1.0, 1.3, float(Coin_amount) / float(Max_coin_amount))
		audio_stream_player_2d.play()
	
	Coin_amount += 1
	
	animate_text()
	
	sprite.hide()
	entity_check_area.disable()
	
	await audio_stream_player_2d.finished
	queue_free()
