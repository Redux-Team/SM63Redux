@tool
extends Node


var _input_handler: InputHandler = InputHandler.new()
var _tree_hook: TreeHook = TreeHook.new()
var _level_clock: LevelClock = LevelClock.new()
var _multiplayer: MultiplayerHandler = MultiplayerHandler.new()


func _init() -> void:
	add_child(_input_handler)
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
