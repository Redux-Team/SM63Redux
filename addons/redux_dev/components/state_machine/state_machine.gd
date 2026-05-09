@icon("uid://c62fk8rmsd0do")
@tool
class_name StateMachine
extends Node


signal state_changed(from: State, to: State)

@export var initial_state: State
@export var root_node: NodePath
@export var sprite: SmartSprite2D
@export var animation_player: AnimationPlayer

@export_group("Internal", "__")
@export var __last__editor_position: Vector2
@export var __last_editor_zoom: float
@export var __states: Dictionary[StringName, State]
@export var __annotations: Dictionary
@export var __transitions: Dictionary[StringName, StateTransition]
@export var __aliases: Dictionary
@export var __entry_node_position: Vector2
@export var __exit_node_position: Vector2
@export var __has_entry: bool
@export var __has_exit: bool
@export var __entry_target_uuid: StringName
@export var __exit_source_uuid: StringName

var _root_node: Node
var _current_state: State
var _active_superstates: Array[State] = []
var _last_state: State
var _elapsed_time: float = 0.0
var _elapsed_frames: int = 0
var _elapsed_physics_frames: int = 0
var _done_requested: bool = false
var _done_forced: bool = false
var _running: bool = false
var _pending_transition: StateTransition = null
var _pending_transition_target: State = null
var _pending_transition_timer: float = 0.0
var _state_buffer: float = 0.0
var _can_consume_buffer: bool = false
var _last_transition: StateTransition = null


func _validate_property(property: Dictionary) -> void:
	if property.name.begins_with("__") and not ReduxPlugin.SHOW_INTERNAL:
		property.usage = PROPERTY_USAGE_NO_EDITOR


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_root_node = get_node_or_null(root_node)
	_dispatch_root_node()
	
	if __has_entry and not __entry_target_uuid.is_empty():
		var entry_state: State = __states.get(__entry_target_uuid) as State
		if entry_state:
			_enter_state(entry_state)
	elif initial_state:
		_enter_state(initial_state)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _running or not _current_state:
		return
	
	if _pending_transition:
		_pending_transition_timer -= delta
		if _pending_transition_timer <= 0.0:
			var t: StateTransition = _pending_transition
			var target: State = _pending_transition_target
			_pending_transition = null
			_pending_transition_target = null
			_pending_transition_timer = 0.0
			_transition_to(t, target)
		return
	
	if _state_buffer > 0.0:
		_state_buffer = max(_state_buffer - delta, 0.0)
	else:
		_can_consume_buffer = false
	
	_elapsed_time += delta
	_elapsed_frames += 1
	
	for state: State in _active_superstates:
		state._sprite_rules()
		state._on_tick(delta)
	_current_state._sprite_rules()
	_current_state._on_tick(delta)
	
	for uuid: StringName in __states:
		var state: State = __states.get(uuid) as State
		if state and not _is_state_in_stack(state):
			state._on_tick_inactive(delta)
	
	var max_cascade: int = 8
	while max_cascade > 0:
		var before: State = _current_state
		_evaluate_transitions()
		if _current_state == before or _pending_transition:
			break
		if not _has_immediate_outgoing_transition():
			break
		max_cascade -= 1


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not _running or not _current_state:
		return
	
	_elapsed_physics_frames += 1
	
	for state: State in _active_superstates:
		state._on_physics_tick(delta)
	_current_state._on_physics_tick(delta)
	
	for uuid: StringName in __states:
		var state: State = __states.get(uuid) as State
		if state and not _is_state_in_stack(state):
			state._on_physics_tick_inactive(delta)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not _running or not _current_state:
		return
	
	for state: State in _active_superstates:
		state._on_input(event)
	_current_state._on_input(event)


func _dispatch_root_node() -> void:
	for uuid: StringName in __states:
		var state: State = __states.get(uuid) as State
		if not state:
			continue
		state.state_machine = self
		state.root_node = _root_node
		state.sprite = sprite
		state.animation_player = animation_player
	
	for tid: StringName in __transitions:
		var t: StateTransition = __transitions.get(tid) as StateTransition
		if not t:
			continue
		t.root_node = _root_node
		t._init_expression()


func _evaluate_transitions() -> void:
	var current_uuid: StringName = ""
	for uuid: StringName in __states:
		if __states.get(uuid) == _current_state:
			current_uuid = uuid
			break
	
	var candidates: Array[StateTransition] = []
	for tid: StringName in __transitions:
		var t: StateTransition = __transitions.get(tid) as StateTransition
		if not t:
			continue
		if t.__from_uuid == current_uuid or __aliases.get(t.__from_uuid, {}).get("original_uuid", "") == current_uuid:
			candidates.append(t)
		else:
			for superstate: State in _active_superstates:
				if not superstate.always_transition:
					continue
				if t.__from_uuid == superstate.__editor_uuid or __aliases.get(t.__from_uuid, {}).get("original_uuid", "") == superstate.__editor_uuid:
					var to_state: State = __states.get(t.__to_uuid) as State
					if not to_state:
						var alias_data: Dictionary = __aliases.get(t.__to_uuid, {})
						to_state = __states.get(alias_data.get("original_uuid", "")) as State
					if to_state and not _is_state_in_stack(to_state):
						candidates.append(t)
					break
	
	candidates.sort_custom(func(a: StateTransition, b: StateTransition) -> bool:
		return a.priority > b.priority)
	
	for t: StateTransition in candidates:
		if _should_fire(t):
			var target: State = __states.get(t.__to_uuid) as State
			if not target:
				var alias_data: Dictionary = __aliases.get(t.__to_uuid, {})
				target = __states.get(alias_data.get("original_uuid", "")) as State
			if target:
				if t.transition_time > 0.0:
					_pending_transition = t
					_pending_transition_target = target
					_pending_transition_timer = t.transition_time
				else:
					_transition_to(t, target)
				return
	
	_done_requested = false
	_done_forced = false


func _has_immediate_outgoing_transition() -> bool:
	var current_uuid: StringName = ""
	for uuid: StringName in __states:
		if __states.get(uuid) == _current_state:
			current_uuid = uuid
			break
	for tid: StringName in __transitions:
		var t: StateTransition = __transitions.get(tid) as StateTransition
		if not t or not t.check_immediately:
			continue
		if t.__from_uuid == current_uuid or __aliases.get(t.__from_uuid, {}).get("original_uuid", "") == current_uuid:
			return true
	return false


func _should_fire(t: StateTransition) -> bool:
	var target: State = __states.get(t.__to_uuid) as State
	if not target:
		var alias_data: Dictionary = __aliases.get(t.__to_uuid, {})
		target = __states.get(alias_data.get("original_uuid", "")) as State
	
	match t.mode:
		StateTransition.TransitionMode.AUTO:
			if not t._should_transition():
				return false
		StateTransition.TransitionMode.WAIT_UNTIL_DONE:
			if not _done_forced and not (_done_requested and t._should_transition()):
				return false
		StateTransition.TransitionMode.WAIT_UNTIL_PARAMETER:
			if t.parameter_name.is_empty() or not _root_node or not _root_node.get(t.parameter_name):
				return false
			if not t._should_transition():
				return false
		StateTransition.TransitionMode.WAIT_UNTIL_EXPRESSION:
			if not t._evaluate_expression() or not t._should_transition():
				return false
		StateTransition.TransitionMode.MANUAL:
			return false
	
	if target and target.is_passthrough:
		return _has_outgoing_transition_from(target)
	
	return true


func _has_outgoing_transition_from(state: State) -> bool:
	if not state._pre_entered:
		state._pre_enter()
		state._pre_entered = true
	
	var uuid: StringName = state.__editor_uuid
	var candidates: Array[StateTransition] = []
	for tid: StringName in __transitions:
		var t: StateTransition = __transitions.get(tid) as StateTransition
		if not t:
			continue
		if t.__from_uuid == uuid or __aliases.get(t.__from_uuid, {}).get("original_uuid", "") == uuid:
			candidates.append(t)
	
	candidates.sort_custom(func(a: StateTransition, b: StateTransition) -> bool:
		return a.priority > b.priority)
	
	for t: StateTransition in candidates:
		if _should_fire(t):
			return true
	return false


func _transition_to(t: StateTransition, target: State) -> void:
	_last_transition = t
	_done_requested = false
	_done_forced = false
	
	var new_superstates: Array[State] = _collect_superstates(target)
	var exiting: Array[State] = []
	for s: State in _active_superstates:
		if s not in new_superstates:
			exiting.append(s)
	var entering: Array[State] = []
	for s: State in new_superstates:
		if s not in _active_superstates:
			entering.append(s)
	
	t._on_before_transition()
	_current_state.__sprite_exit()
	_current_state.__animation_exit()
	
	_current_state._on_exit()
	for s: State in exiting:
		s._on_exit()
	
	var from: State = _current_state
	_last_state = from
	
	_current_state._post_exit()
	for s: State in exiting:
		s._post_exit()
	
	for s: State in entering:
		if not s._pre_entered:
			s._pre_enter()
		s._pre_entered = false
	if not target._pre_entered:
		target._pre_enter()
	target._pre_entered = false
	
	_current_state = target
	_active_superstates = new_superstates
	_elapsed_time = 0.0
	_elapsed_frames = 0
	_elapsed_physics_frames = 0
	
	for s: State in entering:
		s._on_enter()
	target._on_enter()
	target.__sprite_enter()
	target.__animation_enter()
	
	t._on_after_transition()
	state_changed.emit(from, target)


func _enter_state(state: State) -> void:
	_current_state = state
	_active_superstates = _collect_superstates(state)
	_elapsed_time = 0.0
	_elapsed_frames = 0
	_elapsed_physics_frames = 0
	_running = true
	
	for s: State in _active_superstates:
		if not s._pre_entered:
			s._pre_enter()
		s._pre_entered = false
		s._on_enter()
	if not state._pre_entered:
		state._pre_enter()
	state._pre_entered = false
	state._on_enter()
	state._pre_enter()
	state._on_enter()
	state.__sprite_enter()
	state.__animation_enter()


func _collect_superstates(state: State) -> Array[State]:
	var result: Array[State] = []
	var current_uuid: StringName = state.__editor_superstate_uuid
	while not current_uuid.is_empty():
		var superstate: State = __states.get(current_uuid) as State
		if not superstate:
			break
		result.push_front(superstate)
		current_uuid = superstate.__editor_superstate_uuid
	return result


func _is_state_in_stack(state: State) -> bool:
	if state == _current_state:
		return true
	for s: State in _active_superstates:
		if s == state:
			return true
	return false


func _resolve_state_name(state_name: String) -> State:
	for uuid: StringName in __states:
		var state: State = __states.get(uuid) as State
		if not state:
			continue
		if state.__editor_name == state_name.to_snake_case() or state.__editor_name == state_name:
			return state
	return null


func _notify_done(forced: bool) -> void:
	if forced:
		_done_forced = true
	else:
		_done_requested = true



func store_state_buffer(amount: float = 0.1) -> bool:
	_state_buffer = amount
	_can_consume_buffer = false
	return true


func consume_state_buffer() -> bool:
	_can_consume_buffer = true
	return _state_buffer == 0.0


func change_state(state_name: String) -> void:
	var target: State = _resolve_state_name(state_name)
	if not target:
		push_warning("StateMachine: no state found for '%s'" % state_name)
		return
	if not _running:
		_enter_state(target)
		return
	var t: StateTransition = StateTransition.new()
	t.__from_uuid = _current_state.__editor_uuid if _current_state else StringName("")
	t.__to_uuid = target.__editor_uuid
	_transition_to(t, target)


func trigger(transition_label: String) -> void:
	if not _current_state:
		return
	for tid: StringName in __transitions:
		var t: StateTransition = __transitions.get(tid) as StateTransition
		if not t or t.mode != StateTransition.TransitionMode.MANUAL:
			continue
		if t.__from_uuid != _current_state.__editor_uuid:
			continue
		if t.label == transition_label:
			var target: State = __states.get(t.__to_uuid) as State
			if target:
				_transition_to(t, target)
			return


func get_current_state() -> State:
	return _current_state


func get_active_superstates() -> Array[State]:
	return _active_superstates.duplicate()


func is_state_active(state_name: String) -> bool:
	var target: State = _resolve_state_name(state_name)
	if not target:
		return false
	return _is_state_in_stack(target)
