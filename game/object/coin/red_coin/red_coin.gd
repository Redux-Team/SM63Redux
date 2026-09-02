class_name RedCoin
extends Coin

const YELLOW_COIN_REWARD: int = 2
const POWER_REWARD: int = 5
const FLUDD_POWER_REWARD: float = 50.0
const MAX_PITCH_SCALE: float = 1.4
const LABEL_RISE: float = 10.0
const LABEL_FADE_DURATION: float = 0.3
const LABEL_RISE_DURATION: float = 0.5

@export var group: String = "default"
@export var all_collected_sfx: AudioStreamPlayer2D
@export var collect_label: Label

var _collected_count: int = 0:
	get:
		return Level.get_instance().get_red_coin_count(group)
	set(count):
		Level.get_instance().set_red_coin_count(group, count)
var _max_count: int = 0:
	get:
		return Level.get_instance().get_red_coin_max(group)
	set(count):
		Level.get_instance().set_red_coin_max(group, count)


func _ready() -> void:
	super()
	_max_count += 1


func _on_entity_check_area_player_entered(_player: Player) -> void:
	_spawn_collect_particles()
	
	var is_last: bool = _collected_count + 1 == _max_count
	if is_last:
		all_collected_sfx.play()
	else:
		sfx_player.pitch_scale = lerpf(1.0, MAX_PITCH_SCALE, float(_collected_count) / float(_max_count))
		sfx_player.play()
	
	_collected_count += 1
	
	Level.get_instance().add_yellow_coin(YELLOW_COIN_REWARD)
	Level.get_player().add_power(POWER_REWARD)
	Level.get_player().add_fludd_power(FLUDD_POWER_REWARD)
	
	_animate_text()
	_hide_and_disable()
	
	if is_last:
		await all_collected_sfx.finished
	else:
		await sfx_player.finished
	queue_free()


func _animate_text() -> void:
	collect_label.show()
	collect_label.text = str(_collected_count)
	
	var tween: Tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(collect_label, "self_modulate", Color.WHITE, LABEL_FADE_DURATION)
	tween.tween_property(collect_label, "position:y", collect_label.position.y - LABEL_RISE, LABEL_RISE_DURATION)
