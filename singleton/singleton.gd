@tool
extends Node


var _discord_handler: DiscordHandler = DiscordHandler.new()
var _input_handler: InputHandler = InputHandler.new()
var _tree_hook: TreeHook = TreeHook.new()
var _level_clock: LevelClock = LevelClock.new()
var _multiplayer: MultiplayerHandler = MultiplayerHandler.new()


func _init() -> void:
	add_child(_input_handler)
	add_child(_discord_handler)
	add_child(_tree_hook)
	add_child(_level_clock)
	add_child(_multiplayer)


func _ready() -> void:
	every(1, func() -> void:
		if get_multiplayer_handler().is_server():
			for n: CanvasItem in get_tree().get_nodes_in_group(&"gui_mp_host"):
				n.show()
		else:
			for n: CanvasItem in get_tree().get_nodes_in_group(&"gui_mp_client"):
				n.show()
	)


func get_version() -> String:
	return ProjectSettings.get_setting("application/config/version")


func get_input_handler() -> InputHandler:
	return _input_handler

## This is a hook which can be used by custom resources to allow syncing
## with the SceneTree process.
func get_tree_hook() -> TreeHook:
	return _tree_hook


func get_level_clock() -> LevelClock:
	return _level_clock


func get_discord_handler() -> DiscordHandler:
	return _discord_handler


func get_multiplayer_handler() -> MultiplayerHandler:
	return _multiplayer


func every(interval: float, method: Callable) -> void:
	var timer: Timer = Timer.new()
	timer.wait_time = interval
	timer.autostart = true
	timer.timeout.connect(method)
	add_child(timer)


class InputHandler:
	extends Node
	
	signal input_type_changed
	
	enum InputType {
		KEYBOARD,
		CONTROLLER,
		TOUCH
	}
	
	var _current_input_type: InputType
	
	func _unhandled_input(event: InputEvent) -> void:
		var _old_input_type: InputType = _current_input_type
		
		if event is InputEventKey:
			_current_input_type = InputType.KEYBOARD
		elif event is InputEventJoypadMotion or event is InputEventJoypadButton:
			_current_input_type = InputType.CONTROLLER
		elif event is InputEventScreenTouch or event is InputEventScreenDrag:
			_current_input_type = InputType.TOUCH
		
		if _old_input_type != _current_input_type:
			input_type_changed.emit()
	
	
	func get_current_input_type() -> InputType:
		return _current_input_type
	
	
	func is_using_keyboard() -> bool:
		return _current_input_type == InputType.KEYBOARD
	
	func is_using_controller() -> bool:
		return _current_input_type == InputType.CONTROLLER
	
	func is_using_touch() -> bool:
		return _current_input_type == InputType.TOUCH


class TreeHook:
	extends Node
	
	var _last_delta: float
	var _frame_bound_callables: Dictionary[Callable, Array]
	
	
	func _process(delta: float) -> void:
		for callable: Callable in _frame_bound_callables:
			callable.callv(_frame_bound_callables.get(callable))
		
		_last_delta = delta
	
	
	func get_last_delta() -> float:
		return _last_delta
	
	
	func bind_callable_to_frame(callable: Callable, parameters: Array) -> void:
		_frame_bound_callables.set(callable, parameters)


class DiscordHandler:
	extends Node
	
	const APPLICATION_ID: int = 1496255367607488562
	
	var _client: DiscordClient = DiscordClient.new()
	var _timestamp: DiscordActivityTimestamps = DiscordActivityTimestamps.new()
	var _timer: Timer = Timer.new()
	var _is_ready: bool = false
	
	
	func _init() -> void:
		_client.set_application_id(APPLICATION_ID)
		_client.set_status_changed_callback(_on_status_changed)
		_timestamp.set_start(int(Time.get_unix_time_from_system()))
	
	
	func _ready() -> void:
		add_child(_timer)
		_timer.wait_time = 1.0
		_timer.timeout.connect(_on_timer_timeout)
		_timer.start()
	
	
	func set_presence(details: String = "", state: String = "") -> void:
		var activity: DiscordActivity = _build_activity(details, state)
		activity.set_assets(_build_assets())
		activity.set_timestamps(_timestamp)
		_client.update_rich_presence(activity, _on_presence_updated)
	
	
	func set_presence_with_assets(
		details: String = "",
		state: String = "",
		large_image: String = "",
		large_text: String = "",
		small_image: String = "",
		small_text: String = ""
	) -> void:
		var activity: DiscordActivity = _build_activity(details, state)
		var assets: DiscordActivityAssets = _build_assets(large_image, large_text)
		if not small_image.is_empty():
			assets.set_small_image(small_image)
		if not small_text.is_empty():
			assets.set_small_text(small_text)
		activity.set_assets(assets)
		_client.update_rich_presence(activity, _on_presence_updated)
	
	
	func set_presence_with_party(
		details: String = "",
		state: String = "",
		party_id: String = "",
		current_size: int = 1,
		max_size: int = 1
	) -> void:
		var activity: DiscordActivity = _build_activity(details, state)
		activity.set_assets(_build_assets())
		if not party_id.is_empty():
			var party: DiscordActivityParty = DiscordActivityParty.new()
			party.set_id(party_id)
			party.set_current_size(current_size)
			party.set_max_size(max_size)
			activity.set_party(party)
		_client.update_rich_presence(activity, _on_presence_updated)
	
	
	func clear_presence() -> void:
		_client.update_rich_presence(DiscordActivity.new(), _on_presence_updated)
	
	
	func is_ready() -> bool:
		return _is_ready
	
	
	func _build_activity(details: String = "", state: String = "") -> DiscordActivity:
		var activity: DiscordActivity = DiscordActivity.new()
		activity.set_type(DiscordActivityTypes.PLAYING)
		if not details.is_empty():
			activity.set_details(details)
		if not state.is_empty():
			activity.set_state(state)
		return activity
	
	
	func _build_assets(large_image: String = "icon", large_text: String = "") -> DiscordActivityAssets:
		var assets: DiscordActivityAssets = DiscordActivityAssets.new()
		assets.set_large_image(large_image)
		assets.set_large_text(large_text if not large_text.is_empty() else "v" + Singleton.get_version())
		return assets
	
	
	func _on_timer_timeout() -> void:
		Discord.run_callbacks()
	
	
	func _on_status_changed(status: DiscordClientStatus.Enum, _error: DiscordClientError.Enum, _error_detail: int) -> void:
		_is_ready = status == DiscordClientStatus.READY
	
	
	func _on_presence_updated(_result: DiscordClientResult) -> void:
		pass


class LevelClock:
	extends Node
	
	var _time: float = 0.0
	var _running: bool = false
	
	
	func _process(delta: float) -> void:
		if _running:
			_time += delta
	
	
	func start(offset: float = 0.0) -> void:
		_time = offset
		_running = true
	
	
	func resume() -> void:
		_running = true
	
	
	func stop() -> void:
		_running = false
	
	
	func get_elapsed_time() -> float:
		return _time


class MultiplayerHandler:
	extends Node
	
	var peer: ENetMultiplayerPeer
	
	signal server_started
	signal client_connected
	
	
	func start_server() -> void:
		peer = ENetMultiplayerPeer.new()
		var err: Error = peer.create_server(get_port())
		if err != OK:
			push_error("Failed to start server: " + error_string(err))
			return
		multiplayer.multiplayer_peer = peer
		server_started.emit()
	
	
	func start_client() -> void:
		peer = ENetMultiplayerPeer.new()
		var err: Error = peer.create_client(get_ip(), get_port())
		if err != OK:
			push_error("Failed to connect: " + error_string(err))
			return
		multiplayer.multiplayer_peer = peer
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	
	
	func get_ip() -> String:
		return env.get_env("IP", "localhost")
	
	
	func get_port() -> int:
		return int(env.get_env("PORT", "42069"))
	
	
	func is_server() -> bool:
		return multiplayer.is_server()
	
	
	func _on_connected_to_server() -> void:
		client_connected.emit()


class env:
	static func get_env(key: String, default: String = "") -> String:
		if has_env():
			var file: FileAccess = FileAccess.open("res://.env", FileAccess.READ)
			var file_content: String = file.get_as_text()
			
			var lines: PackedStringArray = file_content.split("\n")
			
			for line: String in lines:
				if line.begins_with(key):
					return line.split("=", true, 1).get(1)
		return default
	
	
	static func has_env() -> bool:
		return FileAccess.file_exists("res://.env")
