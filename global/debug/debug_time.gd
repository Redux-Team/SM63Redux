class_name DebugTime
extends Node

signal rewind_requested

const SCALE_DOWN_KEY: Key = KEY_BRACKETLEFT
const SCALE_UP_KEY: Key = KEY_BRACKETRIGHT
const STEP_KEY: Key = KEY_PERIOD
const REWIND_KEY: Key = KEY_COMMA
const SCALES: Array[float] = [0.0, 0.1, 0.25, 0.5, 1.0, 1.25, 1.5, 2.0, 4.0, 8.0]
const DEFAULT_INDEX: int = 4

var _index: int = DEFAULT_INDEX
var _base_physics_ticks: int = 60
var _step_frames: int = 0
var _step_done: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_base_physics_ticks = Engine.physics_ticks_per_second


func _physics_process(_delta: float) -> void:
	if _step_frames <= 0:
		return
	
	_step_frames -= 1
	_step_done = _step_frames <= 0


func _process(_delta: float) -> void:
	if _index != DEFAULT_INDEX and not is_in_level():
		reset()
	
	if _step_done:
		_step_done = false
		get_tree().paused = true


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if not key or not key.pressed or key.echo or not Singleton.debug_display_shown or not is_in_level():
		return
	
	match key.keycode:
		SCALE_DOWN_KEY:
			shift(-1)
		SCALE_UP_KEY:
			shift(1)
		STEP_KEY:
			step()
		REWIND_KEY:
			if is_frozen():
				rewind_requested.emit()
		_:
			return
	
	get_viewport().set_input_as_handled()


func shift(direction: int) -> void:
	_index = clampi(_index + direction, 0, SCALES.size() - 1)
	_apply()


func step() -> void:
	if not is_frozen():
		return
	
	_step_frames = 1
	get_tree().paused = false


func reset() -> void:
	_index = DEFAULT_INDEX
	_apply()


func get_scale() -> float:
	return SCALES.get(_index)


func is_frozen() -> bool:
	return get_scale() <= 0.0


func is_in_level() -> bool:
	return get_tree().get_first_node_in_group(&"level") != null


func _apply() -> void:
	var scale: float = 1.0 if is_frozen() else get_scale()
	_step_frames = 0
	_step_done = false
	Engine.time_scale = scale
	Engine.physics_ticks_per_second = roundi(_base_physics_ticks * scale)
	get_tree().paused = is_frozen()
