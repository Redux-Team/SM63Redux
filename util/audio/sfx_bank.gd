class_name SFXBank
extends Resource


enum PlayOrder {
	RANDOM,
	RANDOM_ONCE,
	RANDOM_NEW,
	SEQUENTIAL,
}

static var all_banks: Array[SFXBank] = []

@export var sound_effects: Array[AudioStream] ## The pool of audio streams to draw from.
@export var play_order: PlayOrder ## Determines the order in which streams are selected.
@export var repeat_list: bool = true ## Whether the list restarts after exhaustion.
@export var max_stack: int = 1 ## Maximum number of simultaneous players.
@export var interval: float = 0.0 ## Minimum time in seconds between plays. In frame-driven mode, acts as a cooldown buffer.
@export var overwrite_group: bool = false ## Stops all other banks in the same group before playing.
@export var bank_group: StringName ## Group identifier used for overwrite and is_in_group checks.
@export_group("Terrain SFX")
@export var terrain_exclusive: bool = false ## If true, only terrain SFX play; base sound_effects are ignored.
@export var terrain_sfx_entries: Dictionary[StringName, Array] ## Map of terrain key to Array[AudioStream].
@export_group("Entity")
@export var stop_on_state_exit: bool = false ## If true, prevents stream cleanup when a player finishes, expecting the state to manage it.
@export var sprite_frame_indices: Array[int] ## If non-empty, playback is gated to only these sprite frames.

var _entity: Entity
var _sprite: SmartSprite2D


var _current_index: int = 0
var _shuffled_indices: Array[int] = []
var _last_played_index: int = -1
var _last_frame_played: int = -1
var _active_players: Array[Node] = []
var _last_play_time: float = -INF


func _init() -> void:
	if not all_banks.has(self):
		all_banks.append(self)


func play_sfx(bus: StringName = bank_group, entity: Entity = null, sprite: SmartSprite2D = null) -> void:
	_entity = entity
	_sprite = sprite
	var current_time: float = Time.get_ticks_msec() / 1000.0
	if interval == 0.0:
		if Engine.get_frames_drawn() == _last_frame_played:
			return
	elif current_time - _last_play_time < interval:
		return
	if not _sprite_frame_valid():
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
	_last_frame_played = Engine.get_frames_drawn()
	var player: AudioStreamPlayer = _get_available_global_player()
	if player == null:
		return
	player.stream = effects[index]
	player.bus = bus
	player.play()


func play_sfx_at(at: Variant, bus: StringName = bank_group, entity: Entity = null, sprite: SmartSprite2D = null) -> void:
	_entity = entity
	_sprite = sprite
	var current_time: float = Time.get_ticks_msec() / 1000.0
	if current_time - _last_play_time < interval:
		return
	if not _sprite_frame_valid():
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
	var player: AudioStreamPlayer2D = _get_available_2d_player()
	if player == null:
		return
	if at is Node2D:
		var target: Node2D = at as Node2D
		if player.get_parent() != target:
			if player.is_inside_tree():
				player.reparent(target)
			else:
				target.add_child(player)
	else:
		if not player.is_inside_tree():
			Singleton.add_child(player)
		player.global_position = at as Vector2
	player.stream = effects[index]
	player.bus = bus
	player.play()


func _sprite_frame_valid() -> bool:
	if sprite_frame_indices.is_empty():
		return true
	if _sprite == null:
		return false
	return sprite_frame_indices.has(_sprite.current_frame)


func stop_all() -> void:
	for player: Node in _active_players:
		if player is AudioStreamPlayer and (player as AudioStreamPlayer).playing:
			(player as AudioStreamPlayer).stop()
		elif player is AudioStreamPlayer2D and (player as AudioStreamPlayer2D).playing:
			(player as AudioStreamPlayer2D).stop()


func is_in_group(group: StringName) -> bool:
	return bank_group == group or group == &"All" or bank_group == &"All"


func reset() -> void:
	_current_index = 0
	_shuffled_indices.clear()
	_last_played_index = -1
	_last_play_time = -INF
	_last_frame_played = -1
	stop_all()


func cleanup() -> void:
	for player: Node in _active_players:
		if player != null:
			player.queue_free()
	_active_players.clear()
	all_banks.erase(self)


func _stop_group_banks() -> void:
	for bank: SFXBank in all_banks:
		if bank != self and bank != null and bank.is_in_group(bank_group):
			bank.stop_all()


func _get_active_sound_effects() -> Array[AudioStream]:
	var terrain_effects: Array[AudioStream] = _get_terrain_effects()
	if terrain_effects.is_empty():
		return sound_effects
	if terrain_exclusive:
		return terrain_effects
	var combined: Array[AudioStream] = []
	combined.append_array(sound_effects)
	combined.append_array(terrain_effects)
	return combined


func _get_terrain_effects() -> Array[AudioStream]:
	if _entity == null or terrain_sfx_entries.is_empty():
		return []
	var terrain_key: StringName = _entity.get_terrain()
	if not terrain_sfx_entries.has(terrain_key):
		return []
	var result: Array[AudioStream] = []
	for stream: AudioStream in terrain_sfx_entries[terrain_key]:
		result.append(stream)
	return result


func _get_available_global_player() -> AudioStreamPlayer:
	for player: Node in _active_players:
		if player is AudioStreamPlayer and not (player as AudioStreamPlayer).playing:
			return player as AudioStreamPlayer
	if _active_players.size() < max_stack:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.finished.connect(_on_player_finished.bind(player))
		Singleton.add_child(player)
		_active_players.append(player)
		return player
	return null


func _get_available_2d_player() -> AudioStreamPlayer2D:
	for player: Node in _active_players:
		if player is AudioStreamPlayer2D and not (player as AudioStreamPlayer2D).playing:
			return player as AudioStreamPlayer2D
	if _active_players.size() < max_stack:
		var player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
		player.finished.connect(_on_player_finished.bind(player))
		_active_players.append(player)
		return player
	return null


func _on_player_finished(player: Node) -> void:
	if stop_on_state_exit:
		return
	if player is AudioStreamPlayer:
		(player as AudioStreamPlayer).stream = null
	elif player is AudioStreamPlayer2D:
		(player as AudioStreamPlayer2D).stream = null


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
