class_name SFXBank
extends Resource


enum PlayOrder {
	RANDOM,
	RANDOM_ONCE,
	RANDOM_NEW,
	SEQUENTIAL,
}


@export var sound_effects: Array[AudioStream]
@export var play_order: PlayOrder
@export var repeat_list: bool = true
@export var max_stack: int = 1
@export var interval: float = 0.0
@export var overwrite_group: bool = false
@export var bank_group: StringName
@export_group("Terrain SFX")
@export var terrain: SFX.TerrainType = SFX.TerrainType.GENERIC
@export var terrain_exclusive: bool = false
@export var grass_sfx: Array[AudioStream]
@export var snow_sfx: Array[AudioStream]
@export var cloud_sfx: Array[AudioStream]
@export var sand_sfx: Array[AudioStream]
@export_group("Entity")
@export var stop_on_state_exit: bool = false

static var _all_banks: Array[SFXBank] = []

var _current_index: int = 0
var _shuffled_indices: Array[int] = []
var _last_played_index: int = -1
var _active_players: Array[AudioStreamPlayer] = []
var _last_play_time: float = -INF


func _init() -> void:
	if not _all_banks.has(self):
		_all_banks.append(self)


func play_sfx() -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	if current_time - _last_play_time < interval:
		return
	
	if overwrite_group:
		_stop_group_banks()
	
	var effects: Array[AudioStream] = _get_active_sound_effects()
	if effects.is_empty():
		return
	
	var index: int = _get_next_index(effects)
	if index == -1:
		return
	
	_last_played_index = index
	_last_play_time = current_time
	
	var player: AudioStreamPlayer = _get_available_player()
	if player == null:
		return
	
	player.stream = effects[index]
	player.play()


func stop_all() -> void:
	for player: AudioStreamPlayer in _active_players:
		if player != null and player.playing:
			player.stop()


func is_in_group(group: StringName) -> bool:
	return bank_group == group or group == &"All" or bank_group == &"All"


func _stop_group_banks() -> void:
	for bank: SFXBank in _all_banks:
		if bank != self and bank != null and bank.is_in_group(bank_group):
			bank.stop_all()


func _get_active_sound_effects() -> Array[AudioStream]:
	var terrain_effects: Array[AudioStream] = _get_terrain_effects()
	
	if terrain == SFX.TerrainType.GENERIC:
		return sound_effects
	
	if terrain_exclusive:
		return terrain_effects
	
	var combined: Array[AudioStream] = []
	combined.append_array(sound_effects)
	combined.append_array(terrain_effects)
	return combined


func _get_terrain_effects() -> Array[AudioStream]:
	match terrain:
		SFX.TerrainType.GRASS:
			return grass_sfx
		SFX.TerrainType.SAND:
			return sand_sfx
		SFX.TerrainType.SNOW:
			return snow_sfx
		SFX.TerrainType.CLOUD:
			return cloud_sfx
		_:
			return []


func _get_available_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _active_players:
		if player != null and not player.playing:
			return player
	
	if _active_players.size() < max_stack:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.finished.connect(_on_player_finished.bind(player))
		Singleton.add_child(player)
		_active_players.append(player)
		return player
	
	return null


func _on_player_finished(player: AudioStreamPlayer) -> void:
	if stop_on_state_exit:
		return
	
	if player != null and not player.playing:
		player.stream = null


func _get_next_index(effects: Array[AudioStream]) -> int:
	match play_order:
		PlayOrder.RANDOM:
			return randi() % effects.size()
		
		PlayOrder.RANDOM_ONCE:
			if _shuffled_indices.is_empty():
				_shuffled_indices = _create_shuffled_indices(effects)
			
			if _current_index >= _shuffled_indices.size():
				if not repeat_list:
					return -1
				_current_index = 0
				_shuffled_indices = _create_shuffled_indices(effects)
			
			var index: int = _shuffled_indices[_current_index]
			_current_index += 1
			return index
		
		PlayOrder.RANDOM_NEW:
			if effects.size() == 1:
				return 0
			
			var index: int = randi() % effects.size()
			while index == _last_played_index:
				index = randi() % effects.size()
			return index
		
		PlayOrder.SEQUENTIAL:
			if _current_index >= effects.size():
				if not repeat_list:
					return -1
				_current_index = 0
			
			var index: int = _current_index
			_current_index += 1
			return index
	
	return -1


func _create_shuffled_indices(effects: Array[AudioStream]) -> Array[int]:
	var indices: Array[int] = []
	for i: int in effects.size():
		indices.append(i)
	
	indices.shuffle()
	return indices


func reset() -> void:
	_current_index = 0
	_shuffled_indices.clear()
	_last_played_index = -1
	_last_play_time = -INF
	stop_all()


func cleanup() -> void:
	for player: AudioStreamPlayer in _active_players:
		if player != null:
			player.queue_free()
	_active_players.clear()
	_all_banks.erase(self)
