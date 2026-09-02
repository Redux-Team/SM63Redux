@tool
class_name StateMachine
extends Node


signal state_changed(from: State, to: State)

const HISTORY_SIZE: int = 20

@export var entity: Entity
@export var initial_state: State
@export var animation_player: AnimationPlayer
@export var default_sfx_bus: StringName = &"SFX"

var _current: State
var _previous: State
var last_variant_index: int = 0
var _stack: Array[State] = []
var _states: Dictionary[StringName, State] = {}
var _history: Array[StringName] = []
var _queued: State
var _running: bool = false
var _locked: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_build()
	if initial_state:
		_switch_to(initial_state)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not _running:
		return
	
	_locked = true
	for state: State in _stack:
		state.time += delta
		state.frames += 1
		state._tick(delta)
	_locked = false
	
	if _queued:
		var target: State = _queued
		_queued = null
		_switch_to(target)
	
	_poll()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _running:
		return
	
	for state: State in _stack:
		state._render_tick(delta)
		if state.effects:
			state.effects.render_tick(state)


func change_state(state_name: StringName) -> void:
	var target: State = _states.get(state_name)
	if not target:
		push_error("StateMachine (%s): no state named '%s'" % [_owner_name(), state_name])
		return
	
	if _locked:
		_queued = target
		return
	_switch_to(target)


func get_state() -> State:
	return _current


func get_last_state() -> State:
	return _previous


func get_state_name() -> StringName:
	return _current.name if _current else &""


func is_active(state_name: StringName) -> bool:
	var target: State = _states.get(state_name)
	return target != null and _stack.has(target)


func get_history() -> Array[StringName]:
	return _history.duplicate()


func get_active_states() -> Array[State]:
	return _stack.duplicate()


func restore_state(state_name: StringName) -> void:
	var target: State = _states.get(state_name)
	if not target or target == _current:
		return
	
	_previous = _current
	_current = target
	_stack = _build_stack(target)


func stop() -> void:
	if not _running:
		return
	
	for index: int in range(_stack.size() - 1, -1, -1):
		_exit_state(_stack.get(index))
	_running = false
	_current = null
	_queued = null
	_stack = []


func _build() -> void:
	_states.clear()
	_register(self)


func _register(node: Node) -> void:
	for child: Node in node.get_children():
		if child is State:
			var state: State = child as State
			state.machine = self
			state.entity = entity
			state.sprite = entity.sprite if entity else null
			state._bind()
			_add_name(state.name, state)
			var snake: StringName = StringName(String(state.name).to_snake_case())
			if snake != state.name:
				_add_name(snake, state)
			_register(state)


func _add_name(state_name: StringName, state: State) -> void:
	var existing: State = _states.get(state_name)
	if existing and existing != state:
		push_error("StateMachine (%s): duplicate state name '%s'" % [_owner_name(), state_name])
		return
	_states.set(state_name, state)


func _poll() -> void:
	var requested: StringName = _request_from_stack()
	if requested.is_empty():
		return
	
	var target: State = _states.get(requested)
	if not target:
		push_error("StateMachine (%s): '%s' requested unknown state '%s'" % [_owner_name(), _current.name, requested])
		return
	if target != _current:
		_switch_to(target)


func _request_from_stack() -> StringName:
	for index: int in range(_stack.size() - 1, -1, -1):
		var requested: StringName = _stack.get(index)._next()
		if not requested.is_empty():
			return requested
	return &""


func _switch_to(target: State) -> void:
	var from: State = _current
	var previous: Array[State] = _stack
	var next_stack: Array[State] = _build_stack(target)
	
	for index: int in range(previous.size() - 1, -1, -1):
		var state: State = previous.get(index)
		if not next_stack.has(state):
			_exit_state(state)
	
	_previous = from
	_current = target
	_stack = next_stack
	_running = true
	
	_history.append(target.name)
	if _history.size() > HISTORY_SIZE:
		_history.remove_at(0)
	
	for state: State in next_stack:
		if not previous.has(state):
			_enter_state(state)
	
	state_changed.emit(from, target)


func _enter_state(state: State) -> void:
	state.time = 0.0
	state.frames = 0
	state.sfx_frame_index = -1
	if state.effects:
		state.effects.enter(state)
	state._enter()


func _exit_state(state: State) -> void:
	state._exit()
	if state.effects:
		state.effects.exit(state)


func _build_stack(state: State) -> Array[State]:
	var stack: Array[State] = [state]
	var parent: Node = state.get_parent()
	while parent is State:
		stack.push_front(parent as State)
		parent = parent.get_parent()
	return stack


func _owner_name() -> String:
	return String(entity.name) if entity else String(name)


func _validate_property(property: Dictionary) -> void:
	if property.name == &"default_sfx_bus":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = _bus_hint_string()


func _bus_hint_string() -> String:
	var names: PackedStringArray = []
	for i: int in AudioServer.get_bus_count():
		names.append(AudioServer.get_bus_name(i))
	return ",".join(names)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not entity:
		warnings.append("No entity assigned.")
	if not initial_state:
		warnings.append("No initial state assigned.")
	elif not is_ancestor_of(initial_state):
		warnings.append("The initial state is not a descendant of this machine.")
	
	var seen: Dictionary[StringName, bool] = {}
	for state: State in find_children("*", "State", true, false):
		if seen.has(state.name):
			warnings.append("Duplicate state name '%s'." % state.name)
		seen.set(state.name, true)
	return warnings
