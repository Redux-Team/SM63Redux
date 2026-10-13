class_name ModeMachine
extends Node


signal mode_started(mode: Mode)
signal mode_stopped(mode: Mode)


@export var host: Node


var _modes: Dictionary[StringName, Mode] = {}
var _selected: Mode
var _running: Mode


func _ready() -> void:
	for child: Node in get_children():
		if child is not Mode:
			continue
		
		var mode: Mode = child as Mode
		mode.machine = self
		mode.host = host
		mode._bind()
		_modes.set(mode.name, mode)


func select(mode_name: StringName) -> void:
	var target: Mode = _modes.get(mode_name)
	if target == _selected:
		return
	
	_selected = target
	if target == null and mode_name != &"":
		push_error("ModeMachine (%s): no mode named '%s'" % [name, mode_name])


func tick(delta: float, wanted: bool = true) -> void:
	var target: Mode = _selected if wanted and _selected and _selected._is_available() else null
	
	if target != _running:
		_stop_running()
		_running = target
		if _running:
			_running.time = 0.0
			_running.frames = 0
			_running._enter()
			mode_started.emit(_running)
	
	if not _running:
		return
	
	_running.time += delta
	_running.frames += 1
	_running._tick(delta)


func get_running() -> Mode:
	return _running


func get_selected() -> Mode:
	return _selected


func get_mode(mode_name: StringName) -> Mode:
	return _modes.get(mode_name)


func get_modes() -> Array[Mode]:
	var result: Array[Mode] = []
	for mode_name: StringName in _modes:
		result.append(_modes.get(mode_name))
	
	return result


func is_running(mode_name: StringName) -> bool:
	return _running != null and _running.name == mode_name


func stop() -> void:
	_stop_running()


func _stop_running() -> void:
	if not _running:
		return
	
	var stopped: Mode = _running
	_running = null
	stopped._exit()
	mode_stopped.emit(stopped)
