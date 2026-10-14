class_name RedCoin
extends Coin

const YELLOW_COIN_REWARD: int = 2
const POWER_REWARD: int = 5
const FLUDD_POWER_REWARD: float = 50.0
const MAX_PITCH_SCALE: float = 1.4
const LABEL_RISE: float = 10.0
const LABEL_FADE_DURATION: float = 0.3
const LABEL_RISE_DURATION: float = 0.5

@export var group: StringName = &"default"
@export var all_collected_sfx: AudioStreamPlayer2D
@export var collect_label: Label


func _on_init() -> void:
	super()
	var level: Level = Level.of(self)
	if level:
		level.register_coin(&"red", group)


func _on_entity_check_area_player_entered(player: Player) -> void:
	_spawn_collect_particles()
	var level: Level = Level.of(self)
	var counter: Vector2i = level.get_coin_counter(&"red", group) if level else Vector2i(0, 1)
	var is_last: bool = counter.x + 1 >= counter.y
	if is_last:
		all_collected_sfx.play()
	else:
		sfx_player.pitch_scale = lerpf(1.0, MAX_PITCH_SCALE, float(counter.x) / float(maxi(counter.y, 1)))
		sfx_player.play()
	
	if level:
		level.collect_coin(&"red", 1, group)
	reward(player, YELLOW_COIN_REWARD, POWER_REWARD, FLUDD_POWER_REWARD)
	_animate_text(counter.x + 1)
	_hide_and_disable()
	await (all_collected_sfx if is_last else sfx_player).finished
	queue_free()


func _animate_text(count: int) -> void:
	collect_label.show()
	collect_label.text = str(count)
	var tween: Tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(collect_label, ^"self_modulate", Color.WHITE, LABEL_FADE_DURATION)
	tween.tween_property(collect_label, ^"position:y", collect_label.position.y - LABEL_RISE, LABEL_RISE_DURATION)
