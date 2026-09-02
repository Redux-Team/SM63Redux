@tool
extends Node

signal debug_mode_changed
signal debug_rewind_requested

enum DebugMode {
	HIDDEN,
	PROFILING,
	VERBOSE,
}

const DEBUG_TOGGLE_KEY: Key = KEY_SLASH
const TIME_SCALE_DOWN_KEY: Key = KEY_BRACKETLEFT
const TIME_SCALE_UP_KEY: Key = KEY_BRACKETRIGHT
const FRAME_STEP_KEY: Key = KEY_PERIOD
const FRAME_REWIND_KEY: Key = KEY_COMMA
const TIME_SCALES: Array[float] = [0.0, 0.1, 0.25, 0.5, 1.0, 1.25, 1.5, 2.0, 4.0, 8.0]
const TIME_SCALE_DEFAULT_INDEX: int = 4

var _debug_mode: DebugMode = DebugMode.PROFILING
var _time_scale_index: int = TIME_SCALE_DEFAULT_INDEX
var _base_physics_ticks: int = 60
var _step_frames: int = 0
var _step_done: bool = false

var _input_handler: InputHandler = InputHandler.new()
var _tree_hook: TreeHook = TreeHook.new()
var _level_clock: LevelClock = LevelClock.new()
var _multiplayer: MultiplayerHandler = MultiplayerHandler.new()
var _editor_session: EditorSession = EditorSession.new()
var _frame_stats: FrameStats = FrameStats.new()

@export var _screen_transition_rect: ColorRect
@export var _debug_label: Label


## Optional callback consulted before the app closes. It should return true if it handled the
## request (e.g. opened a "save before quitting?" prompt) so the quit is held off; false to let
## the app close normally. The active scene registers/clears it via set_quit_guard/clear_quit_guard.
var _quit_guard: Callable = Callable()


func _init() -> void:
	add_child(_input_handler)
	add_child(_tree_hook)
	add_child(_level_clock)
	add_child(_multiplayer)
	add_child(_frame_stats)


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_base_physics_ticks = Engine.physics_ticks_per_second
	if not Engine.is_editor_hint():
		get_tree().set_auto_accept_quit(false)
	every(1, func() -> void:
		if get_multiplayer_handler().is_server():
			for n: CanvasItem in get_tree().get_nodes_in_group(&"gui_mp_host"):
				n.show()
		else:
			for n: CanvasItem in get_tree().get_nodes_in_group(&"gui_mp_client"):
				n.show()
	)
	_apply_debug_mode()
	_apply_time_scale()


func _physics_process(_delta: float) -> void:
	if _step_frames <= 0:
		return
	
	_step_frames -= 1
	_step_done = _step_frames <= 0


func _process(_delta: float) -> void:
	if not is_in_level() and _time_scale_index != TIME_SCALE_DEFAULT_INDEX:
		reset_time_scale()
	
	if _step_done:
		_step_done = false
		get_tree().paused = true
	
	if not _debug_label.visible:
		return
	
	var debug_text: String = ""
	debug_text += "\"/\" to cycle (%s)\n" % get_debug_mode_name()
	debug_text += "Version: %s\n" % get_version()
	debug_text += "FPS: %s\n" % Engine.get_frames_per_second()
	debug_text += "Average FPS: %.1f\n" % _frame_stats.get_average_fps()
	debug_text += "Process: %.2f ms\n" % (Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	debug_text += "Physics: %.2f ms\n" % (Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	debug_text += "Draw Calls: %.0d\n" % Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	debug_text += "Video Mem: %s\n" % String.humanize_size(int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)))
	debug_text += "Objects: %.0d\n" % Performance.get_monitor(Performance.OBJECT_COUNT)
	debug_text += "Nodes: %.0d\n" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	debug_text += "Resources: %.0d\n" % Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	debug_text += "Orphan Nodes: %.0d\n" % Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	debug_text += "Bodies: %.0d\n" % Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)
	debug_text += "Collision Pairs: %.0d\n" % Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)
	debug_text += "Frame: %.2f ms (peak %.2f)\n" % [_frame_stats.average * 1000.0, _frame_stats.peak * 1000.0]
	if is_in_level():
		debug_text += "\n Time scale: %sx\n" % [get_time_scale()]
		debug_text += "\"[\" and \"]\" to adjust"
		if is_time_frozen():
			debug_text += "\n\".\" to advance a frame"
			debug_text += "\n\",\" to rewind a frame"
	_debug_label.text = debug_text


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if not key or not key.pressed or key.echo:
		return
	
	match key.keycode:
		DEBUG_TOGGLE_KEY:
			set_debug_mode(((_debug_mode + 1) % DebugMode.size()) as DebugMode)
		TIME_SCALE_DOWN_KEY:
			shift_time_scale(-1)
		TIME_SCALE_UP_KEY:
			shift_time_scale(1)
		FRAME_STEP_KEY:
			step_frame()
		FRAME_REWIND_KEY:
			rewind_frame()


func shift_time_scale(direction: int) -> void:
	if _debug_mode == DebugMode.HIDDEN or not is_in_level():
		return
	
	_time_scale_index = clampi(_time_scale_index + direction, 0, TIME_SCALES.size() - 1)
	_apply_time_scale()


func step_frame() -> void:
	if _debug_mode == DebugMode.HIDDEN or not is_time_frozen() or not is_in_level():
		return
	
	_step_frames = 1
	get_tree().paused = false


func rewind_frame() -> void:
	if _debug_mode == DebugMode.HIDDEN or not is_time_frozen() or not is_in_level():
		return
	
	debug_rewind_requested.emit()


func get_time_scale() -> float:
	return TIME_SCALES.get(_time_scale_index)


func is_in_level() -> bool:
	return is_instance_valid(Level.get_instance())


func reset_time_scale() -> void:
	_time_scale_index = TIME_SCALE_DEFAULT_INDEX
	_apply_time_scale()


func is_time_frozen() -> bool:
	return get_time_scale() <= 0.0


func _apply_time_scale() -> void:
	var frozen: bool = is_time_frozen()
	var scale: float = 1.0 if frozen else get_time_scale()
	
	_step_frames = 0
	_step_done = false
	Engine.time_scale = scale
	Engine.physics_ticks_per_second = roundi(_base_physics_ticks * scale)
	get_tree().paused = frozen
	_set_physics_interpolation(scale < 1.0)


func _set_physics_interpolation(active: bool) -> void:
	if get_tree().physics_interpolation == active:
		return
	
	get_tree().physics_interpolation = active
	if is_instance_valid(get_tree().current_scene):
		get_tree().current_scene.reset_physics_interpolation()


func set_debug_mode(mode: DebugMode) -> void:
	_debug_mode = mode
	_apply_debug_mode()


func get_debug_mode() -> DebugMode:
	return _debug_mode


func get_debug_mode_name() -> String:
	return String(DebugMode.keys().get(_debug_mode)).capitalize()


func is_verbose() -> bool:
	return _debug_mode == DebugMode.VERBOSE


func _apply_debug_mode() -> void:
	_debug_label.visible = _debug_mode != DebugMode.HIDDEN
	debug_mode_changed.emit()


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST or Engine.is_editor_hint():
		return
	if _quit_guard.is_valid() and _quit_guard.call():
		return
	get_tree().quit()


## Registers a callback to intercept app-close requests (see _quit_guard).
func set_quit_guard(guard: Callable) -> void:
	_quit_guard = guard


## Clears the quit guard if it still matches the given callback (so a scene only removes its own).
func clear_quit_guard(guard: Callable) -> void:
	if _quit_guard == guard:
		_quit_guard = Callable()


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


func get_editor_session() -> EditorSession:
	return _editor_session


func build_screen_transition() -> TransitionBuilder:
	return TransitionBuilder.new(_screen_transition_rect)


## True while a screen transition is covering/revealing (the transition rect is shown).
func is_transitioning() -> bool:
	return is_instance_valid(_screen_transition_rect) and _screen_transition_rect.visible


func spawn_sibling(root_node: Node, node: Node, _shared_properties: PackedStringArray = ["position", "scale"]) -> void:
	var parent: Node = root_node.get_parent()
	# The parent can already be on its way out (e.g. spawning from teardown), in which case the
	# deferred add_child is dropped and the node would be stranded outside the tree forever.
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		node.free()
		return
	
	var index: int = root_node.get_index()
	parent.add_child.call_deferred(node)
	parent.move_child.call_deferred(node, index)
	
	for _prop: String in _shared_properties:
		node.set(_prop, root_node.get(_prop))


func instantiate_sibling(root_node: Node, scene: PackedScene, count: int = 1, spread: int = 0, _shared_properties: PackedStringArray = ["position", "scale"]) -> void:
	for c: int in count:
		var node: Node = scene.instantiate()
		spawn_sibling(root_node, node, _shared_properties)
		if not is_instance_valid(node):
			return
		
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


class FrameStats:
	extends Node
	
	const WINDOW: float = 1.0
	
	var average: float = 0.0
	var peak: float = 0.0
	
	var _sum: float = 0.0
	var _frames: int = 0
	var _peak: float = 0.0
	var _last_tick: int = 0
	
	
	func _ready() -> void:
		_last_tick = Time.get_ticks_usec()
	
	
	func _process(_delta: float) -> void:
		var now: int = Time.get_ticks_usec()
		var elapsed: float = float(now - _last_tick) / 1000000.0
		_last_tick = now
		
		_sum += elapsed
		_frames += 1
		_peak = maxf(_peak, elapsed)
		
		if _sum < WINDOW:
			return
		
		average = _sum / _frames
		peak = _peak
		_sum = 0.0
		_frames = 0
		_peak = 0.0
	
	
	func get_average_fps() -> float:
		return 1.0 / average if average > 0.0 else 0.0


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


class TransitionBuilder:
	enum TransitionType { CENTER, WAVE, FADE }
	
	const SHADER_CENTER: Shader = preload("uid://dcewkclyl2vjk")
	const SHADER_WAVE: Shader = preload("uid://drycsk0p628ig")
	const SHADER_FADE: Shader = preload("res://core/shader/screen_transition_fade.gdshader")
	
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
	var _swap: Callable = Callable()
	var _hold_duration: float = 0.5
	var _wave_scale: float = 1.0
	
	
	func _init(color_rect: ColorRect) -> void:
		_color_rect = color_rect
	
	
	func set_type(type: TransitionType) -> TransitionBuilder:
		_type = type
		return self
	
	
	## Wave-shaped transition (e.g. entering the shine select).
	func set_wave() -> TransitionBuilder:
		_type = TransitionType.WAVE
		return self
	
	
	## Mask-shaped center transition (e.g. the shine-out reveal).
	func set_center() -> TransitionBuilder:
		_type = TransitionType.CENTER
		return self
	
	
	## Plain fade to/from a solid color.
	func set_fade() -> TransitionBuilder:
		_type = TransitionType.FADE
		return self
	
	
	## Horizontal tiling count for the wave mask (higher = smaller, more repeated waves).
	func set_wave_scale(scale: float) -> TransitionBuilder:
		_wave_scale = scale
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
	
	
	## Runs instead of loading a scene file, at the same fully-covered moment. Lets a transition
	## swap in a scene that is already in memory (see [EditorSession]).
	func set_swap(swap: Callable) -> TransitionBuilder:
		_swap = swap
		return self
	
	
	func set_hold_duration(duration: float) -> TransitionBuilder:
		_hold_duration = duration
		return self
	
	
	func load(callable: Callable) -> TransitionBuilder:
		_callables.append(callable)
		return self
	
	
	func done() -> void:
		var mat: ShaderMaterial = _color_rect.material as ShaderMaterial
		var wave_aspect: float = 1.0
		match _type:
			TransitionType.CENTER:
				mat.shader = SHADER_CENTER
			TransitionType.WAVE:
				mat.shader = SHADER_WAVE
				mat.set_shader_parameter(&"wave_scale", _wave_scale)
				var vp_size: Vector2 = _color_rect.get_viewport_rect().size
				wave_aspect = vp_size.x / vp_size.y if vp_size.y > 0.0 else 1.0
				mat.set_shader_parameter(&"aspect", wave_aspect)
				# Cover with the wave flipped so it sweeps in from the opposite side; the reveal
				# unflips it (see the WAVE tween below).
				mat.set_shader_parameter(&"flip", true)
			TransitionType.FADE:
				mat.shader = SHADER_FADE
		# Cover with the out mask (falling back to the shared mask); the reveal swaps to the in
		# mask once the screen is fully covered (see tween_out.finished below).
		var cover_tex: Texture2D = _out_texture if is_instance_valid(_out_texture) else _texture
		if is_instance_valid(cover_tex):
			mat.set_shader_parameter(&"mask_texture", cover_tex)
		
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
				# +1 = revealed; the covered offset matches the vertical scale (wave_scale / aspect)
				# so the sweep fully covers. Out covers (flipped), then the reveal unflips and sweeps
				# back. Durations scale with the (shorter) range so the on-screen speed stays constant.
				var scale_y: float = _wave_scale / wave_aspect
				var covered: float = -1.0 / scale_y
				var range_factor: float = (1.0 - covered) / 2.0
				tween_out.tween_method(func(t: float) -> void: mat.set_shader_parameter(&"mask_offset_y", t), 1.0, covered, _out_duration * range_factor)
				tween_in.tween_callback(func() -> void: mat.set_shader_parameter(&"flip", false))
				tween_in.tween_method(func(t: float) -> void: mat.set_shader_parameter(&"mask_offset_y", t), covered, 1.0, _in_duration * range_factor)
			TransitionType.FADE:
				tween_out.tween_method(func(t: float) -> void: mat.set_shader_parameter(&"fade", t), 0.0, 1.0, _out_duration)
				tween_in.tween_method(func(t: float) -> void: mat.set_shader_parameter(&"fade", t), 1.0, 0.0, _in_duration)
		
		tween_out.finished.connect(func() -> void:
			var tree: SceneTree = _color_rect.get_tree()
			# Present a couple of fully-covered frames before running the (possibly heavy) callbacks
			# and again afterwards, so a load hitch hides behind the covered screen instead of
			# freezing on a half-drawn mask.
			await tree.process_frame
			await tree.process_frame
			for c: Callable in _callables:
				c.call()
			await tree.process_frame
			await tree.process_frame
			var hold: Tween = tree.create_tween()
			var reveal_tex: Texture2D = _in_texture if is_instance_valid(_in_texture) else _texture
			if is_instance_valid(reveal_tex):
				mat.set_shader_parameter(&"mask_texture", reveal_tex)
			hold.tween_interval(_hold_duration)
			if _swap.is_valid():
				hold.tween_callback(_swap)
			elif _destination:
				hold.tween_callback(tree.change_scene_to_file.bind(_destination))
			hold.finished.connect(tween_in.play)
		)
		
		tween_in.finished.connect(func() -> void:
			_color_rect.hide()
			_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		)


## Keeps the level designer alive while a playtest runs. Rebuilding the editor and deserializing
## the level back into it costs roughly a second for a thousand-object level and gets worse from
## there; detaching and reattaching the same instance is flat and takes about a tenth of that.
class EditorSession:
	var _held: Node = null


	func is_held() -> bool:
		return is_instance_valid(_held)


	## Detaches the current scene if it is the editor, keeps it, and opens [param scene_path] in
	## its place. Falls back to a plain scene change when there is no editor to hold.
	func suspend_into(tree: SceneTree, scene_path: String) -> void:
		var editor: Node = tree.current_scene
		if not is_instance_valid(editor) or editor is not LD:
			tree.change_scene_to_file(scene_path)
			return

		discard()
		(editor as LD).set_suspended(true)
		tree.root.remove_child(editor)
		_held = editor

		var next: Node = (load(scene_path) as PackedScene).instantiate()
		tree.root.add_child(next)
		tree.current_scene = next


	## Puts the held editor back in place of the current scene. Returns false when nothing is held,
	## so the caller can fall back to loading the editor from disk.
	func resume(tree: SceneTree) -> bool:
		if not is_instance_valid(_held):
			_held = null
			return false

		var editor: Node = _held
		_held = null
		var outgoing: Node = tree.current_scene

		tree.root.add_child(editor)
		(editor as LD).set_suspended(false)
		tree.current_scene = editor
		if is_instance_valid(outgoing) and outgoing != editor:
			outgoing.queue_free()

		# The handover dict only exists to rebuild an editor that was thrown away. The live one
		# already holds this level, so leaving it set would make the next cold open restore it.
		Singleton.remove_meta(&"playtest")
		return true


	## Reattaches the held editor, or loads it from disk when there is nothing held.
	func resume_or_open(tree: SceneTree, scene_path: String) -> void:
		if not resume(tree):
			tree.change_scene_to_file(scene_path)


	## Throws the held editor away, for when the next editor open has to start from scratch.
	func discard() -> void:
		if is_instance_valid(_held):
			_held.queue_free()
		_held = null


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
