@tool
extends Node

var _input_handler: InputHandler = InputHandler.new()
var _tree_hook: TreeHook = TreeHook.new()
var _level_clock: LevelClock = LevelClock.new()
var _multiplayer: MultiplayerHandler = MultiplayerHandler.new()
var _transition_handler: TransitionHandler = TransitionHandler.new()

@export var _screen_transition_rect: ColorRect


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


func build_screen_transition() -> TransitionBuilder:
	return _transition_handler.build()


func spawn_sibling(root_node: Node, node: Node, _shared_properties: PackedStringArray = ["position", "scale"]) -> void:
	var index: int = root_node.get_index()
	root_node.get_parent().add_child.call_deferred(node)
	root_node.get_parent().move_child.call_deferred(node, index)
	
	for _prop: String in _shared_properties:
		node.set(_prop, root_node.get(_prop))


func instantiate_sibling(root_node: Node, scene: PackedScene, count: int = 1, spread: int = 0, _shared_properties: PackedStringArray = ["position", "scale"]) -> void:
	var index: int = root_node.get_index()
	for c: int in count:
		var node: Node = scene.instantiate().duplicate()
		root_node.get_parent().add_child.call_deferred(node)
		root_node.get_parent().move_child.call_deferred(node, index)
		
		for _prop: String in _shared_properties:
			node.set(_prop, root_node.get(_prop))
		
		node.position.x += randi_range(-spread, spread)
		node.position.y += randi_range(-spread, spread)


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


class TransitionHandler:
	extends Node
	
	func build() -> TransitionBuilder:
		return TransitionBuilder.new(Singleton._screen_transition_rect)


class TransitionBuilder:
	enum TransitionType { CENTER, WAVE }
	
	const SHADER_CENTER: Shader = preload("uid://dcewkclyl2vjk")
	const SHADER_WAVE: Shader = preload("uid://drycsk0p628ig")
	
	var _color_rect: ColorRect
	var _type: TransitionType = TransitionType.CENTER
	var _out_duration: float = 0.5
	var _in_duration: float = 0.8
	var _block_input: bool = true
	var _callables: Array[Callable] = []
	var _texture: Texture2D = null
	var _out_texture: Texture2D = null
	var _in_texture: Texture2D = null
	var _destination: String = ""
	var _hold_duration: float = 0.5
	
	
	func _init(color_rect: ColorRect) -> void:
		_color_rect = color_rect
	
	
	func set_type(type: TransitionType) -> TransitionBuilder:
		_type = type
		return self
	
	
	func set_out_duration(duration: float) -> TransitionBuilder:
		_out_duration = duration
		return self
	
	
	func set_in_duration(duration: float) -> TransitionBuilder:
		_in_duration = duration
		return self
	
	
	func set_block_input(block_input: bool) -> TransitionBuilder:
		_block_input = block_input
		return self
	
	
	func set_texture(texture: Texture2D) -> TransitionBuilder:
		_texture = texture
		return self
	
	
	func set_out_texture(texture: Texture2D) -> TransitionBuilder:
		_out_texture = texture
		return self
	
	
	func set_in_texture(texture: Texture2D) -> TransitionBuilder:
		_in_texture = texture
		return self
	
	
	func set_destination(path: String) -> TransitionBuilder:
		_destination = path
		return self
	
	
	func set_hold_duration(duration: float) -> TransitionBuilder:
		_hold_duration = duration
		return self
	
	
	func load(callable: Callable) -> TransitionBuilder:
		_callables.append(callable)
		return self
	
	
	func done() -> void:
		var mat: ShaderMaterial = _color_rect.material as ShaderMaterial
		match _type:
			TransitionType.CENTER:
				mat.shader = SHADER_CENTER
			TransitionType.WAVE:
				mat.shader = SHADER_WAVE
		if is_instance_valid(_texture):
			mat.set_shader_parameter(&"mask_texture", _texture)
		
		_color_rect.show()
		if _block_input:
			_color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var tween_out: Tween = _color_rect.get_tree().create_tween().set_ease(Tween.EASE_OUT)
		var tween_in: Tween = _color_rect.get_tree().create_tween().set_ease(Tween.EASE_IN)
		tween_in.pause()
		
		match _type:
			TransitionType.CENTER:
				tween_out.tween_method(func(t: float) -> void: mat.set_shader_parameter(&"mask_scale", t), 10.0, 0.0, _out_duration)
				tween_in.tween_method(func(t: float) -> void: mat.set_shader_parameter(&"mask_scale", t), 0.0, 10.0, _in_duration)
			TransitionType.WAVE:
				tween_out.tween_method(func(t: float) -> void: mat.set_shader_parameter(&"mask_offset", Vector2(0.0, t)), 1.0, 0.0, _out_duration)
				tween_in.tween_method(func(t: float) -> void: mat.set_shader_parameter(&"mask_offset", Vector2(0.0, t)), 0.0, 1.0, _in_duration)
		
		tween_out.finished.connect(func() -> void:
			for c: Callable in _callables:
				c.call()
			var hold: Tween = _color_rect.get_tree().create_tween()
			var out_tex: Texture2D = _out_texture if is_instance_valid(_out_texture) else _texture
			if is_instance_valid(out_tex):
				mat.set_shader_parameter(&"mask_texture", out_tex)
			hold.tween_interval(_hold_duration)
			if _destination:
				hold.tween_callback(_color_rect.get_tree().change_scene_to_file.bind(_destination))
			hold.finished.connect(tween_in.play)
		)
		
		tween_in.finished.connect(func() -> void:
			_color_rect.hide()
			_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		)


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
