extends Node2D

@export var level_root: Node2D
@export var multiplayer_spawner: MultiplayerSpawner
@export var player_scene: PackedScene

var _level_handler: LevelHandler


func _ready() -> void:
	_level_handler = LevelHandler.new()
	add_child(_level_handler)
	_level_handler.setup(level_root)
	_level_handler.set_multiplayer_spawner(multiplayer_spawner)
	
	multiplayer_spawner.spawn_function = _spawn_player_with_id
	multiplayer_spawner.spawn_path = level_root.get_path()
	
	var mp: Singleton.MultiplayerHandler = Singleton.get_multiplayer_handler()
	
	if mp.is_server():
		if Singleton.has_meta("playtest"):
			_level_handler.load_from_dict(Singleton.get_meta("playtest"))
		Singleton.get_level_clock().start()
		multiplayer_spawner.spawn(multiplayer.get_unique_id())
		multiplayer.peer_connected.connect(_on_peer_connected)


func _spawn_player_with_id(peer_id: int) -> Node:
	var spawned_player: Player = player_scene.instantiate()
	spawned_player.name = str(peer_id)
	spawned_player.multiplayer_id = peer_id
	return spawned_player


func _on_peer_connected(id: int) -> void:
	var elapsed: float = Singleton.get_level_clock().get_elapsed_time()
	_send_level_data.rpc_id(id, Singleton.get_meta("playtest"), id, elapsed)


@rpc("authority", "reliable")
func _send_level_data(data: Dictionary, peer_id: int = 1, elapsed: float = 0.0) -> void:
	_level_handler.load_from_dict(data, peer_id)
	Singleton.get_level_clock().start(elapsed)
	_notify_ready_to_spawn.rpc_id(1)


@rpc("any_peer", "reliable")
func _notify_ready_to_spawn() -> void:
	if not multiplayer.is_server():
		return
	var id: int = multiplayer.get_remote_sender_id()
	multiplayer_spawner.spawn(id)


func _on_back_button_pressed() -> void:
	Singleton.get_level_clock().stop()
	get_tree().change_scene_to_file("uid://cf4yw3eqr2qo6")
