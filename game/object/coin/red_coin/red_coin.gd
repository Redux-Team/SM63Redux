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

var Max_red_coin_amount: int = 0:
	get:
		return Level.get_instance().get_red_coin_max(group)
	set(mca):
		Level.get_instance().set_red_coin_max(group, mca)
var Red_coin_amount: int = 0:
	get:
		return Level.get_instance().get_red_coin_count(group)
	set(ca):
		Level.get_instance().set_red_coin_count(group, ca)
var Yellow_coin_amount: int = 0:
	get:
		return Level.get_instance().get_yellow_coin_count()
	set(ca):
		Level.get_instance().set_yellow_coin_count(ca)


func _ready() -> void:
	scale = Vector2.ONE
	sprite.play(&"default")
	if explode_on_spawn:
		explode(randf_range(-15, 15), 200)
	
	Max_red_coin_amount += 1

## Call this function to make the coin go a random direction
func explode(strength_x: float = 0.0, strength_y: float = 0.0) -> void:
	velocity = Vector2(strength_x * randf_range(0.5, 6.0), -strength_y * randf_range(0.5, 1.5)) / (10.0 if is_in_water() else 1.0)
	gravity_component.enabled = true


func animate_text() -> void:
	collect_label.show()
	collect_label.text = str(Red_coin_amount)
	
	_collect_tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	_collect_tween.tween_property(collect_label, "self_modulate", Color.WHITE, 0.3)
	_collect_tween.tween_property(collect_label, "position:y", collect_label.position.y - 10, 0.5)


func _on_entity_check_area_player_entered(_player: Player) -> void:
	var emitter: ParticleEmitter = particle_emitter.duplicate()
	
	Singleton.spawn_sibling(self, emitter, ["position", "scale", "rotation"])
	
	emitter.emitting = true
	
	if Red_coin_amount + 1 == Max_red_coin_amount:
		all_collected.play()
	else:
		audio_stream_player_2d.pitch_scale = lerpf(1.0, 1.4, float(Red_coin_amount) / float(Max_red_coin_amount))
		audio_stream_player_2d.play()
	
	Red_coin_amount += 1
	
	Level.get_instance().add_yellow_coin(2)
	Level.get_player().add_power(5)
	Level.get_player().add_fludd_power(50)
	
	animate_text()
	
	sprite.hide()
	entity_check_area.disable()
	
	if all_collected.playing:
		await all_collected.finished
	else:
		await audio_stream_player_2d.finished
	queue_free()
