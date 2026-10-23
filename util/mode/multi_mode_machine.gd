class_name MultiModeMachine
extends ModeMachine


@export_group("Debug")
@export var debug_toggles: Dictionary[Key, StringName] = {}
@export var debug_clear_key: Key = KEY_NONE


var _active: Array[Mode] = []


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if not OS.is_debug_build() or not key or not key.pressed or key.echo:
		return
	
	if key.keycode == debug_clear_key:
		stop()
	elif debug_toggles.has(key.keycode):
		toggle(debug_toggles[key.keycode], true)
	else:
		return
	
	get_viewport().set_input_as_handled()


func tick(delta: float, wanted: bool = true) -> void:
	if not wanted:
		return
	
	for mode: Mode in _active.duplicate():
		if not _active.has(mode):
			continue
		
		mode.time += delta
		mode.frames += 1
		mode._tick(delta)


func get_running() -> Mode:
	return _active.back() if not _active.is_empty() else null


func is_running(mode_name: StringName) -> bool:
	return _active.any(func(mode: Mode) -> bool: return mode.name == mode_name)


func stop() -> void:
	for mode: Mode in _active.duplicate():
		end(mode.name)


func start(mode_name: StringName, permanent: bool = false) -> void:
	var mode: Mode = _modes.get(mode_name)
	if not mode:
		push_error("MultiModeMachine (%s): no mode named '%s'" % [name, mode_name])
		return
	
	if _active.has(mode) or not mode._is_available():
		return
	
	mode.time = 0.0
	mode.frames = 0
	mode.permanent = permanent
	_active.append(mode)
	mode._enter()
	mode_started.emit(mode)


func end(mode_name: StringName) -> void:
	var mode: Mode = _modes.get(mode_name)
	if not mode or not _active.has(mode):
		return
	
	_active.erase(mode)
	mode._exit()
	mode_stopped.emit(mode)


func toggle(mode_name: StringName, permanent: bool = false) -> void:
	if is_running(mode_name):
		end(mode_name)
	else:
		start(mode_name, permanent)


func get_running_modes() -> Array[Mode]:
	return _active.duplicate()
