## Holds and organizes [State] resources, driving transitions between them.
##
## [StateMachine] is the central runtime controller for a node-based state graph.
## It owns all [State] and [StateTransition] resources, evaluates transition conditions
## on the fixed physics clock, manages superstate stacks, and dispatches lifecycle callbacks
## ([method State._on_enter], [method State._on_physics_tick], [method State._on_exit], etc.)
## to active states. Sprite rules and animation hooks are also coordinated here. [br][br]
## All gameplay logic and transition evaluation run in [method _physics_process] so behavior
## is identical at any render framerate; [method _process] only drives visual, render-rate hooks
## ([method State._sprite_rules] and [method State._on_render_tick]). [br][br]
## This StateMachine does not require the Redux Development Plugin to run, however it is
## recommended to use it in order to [b]edit[/b] everything in the StateMachine.
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
var _current_uuid: StringName = &""
var _active_superstates: Array[State] = []
var _last_state: State
var _next_state: State
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
var _has_always_superstate: bool = false
var _uuid_of_state: Dictionary[State, StringName] = {}
var _alias_target: Dictionary[StringName, StringName] = {}
var _out_transitions: Dictionary[StringName, Array] = {}
var _transition_target: Dictionary[StateTransition, State] = {}
var _immediate_out: Dictionary[StringName, bool] = {}


# hides __ prefixed properties from the inspector unless SHOW_INTERNAL is set in the development plugin.
func _validate_property(property: Dictionary) -> void:
	if property.name.begins_with("__") and not ReduxPlugin.SHOW_INTERNAL:
		property.usage = PROPERTY_USAGE_NO_EDITOR


# resolves the root node, builds lookup tables, and enters the initial or entry-linked state.
func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_root_node = get_node_or_null(root_node)
	_dispatch_root_node()
	_build_tables()

	var entry_state: State = _resolve_entry_state()
	if entry_state:
		_enter_state(entry_state)


# Drives render-rate visual hooks only. No logic, timers, or transitions run here.
func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _running or not _current_state:
		return

	_elapsed_frames += 1
	for state: State in _active_superstates:
		state._sprite_rules()
		state._on_render_tick(delta)
	_current_state._sprite_rules()
	_current_state._on_render_tick(delta)


# The single fixed-timestep clock: all logic, timers, and transition evaluation happen here.
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not _running or not _current_state:
		return

	_fixed_step(delta)


func _fixed_step(delta: float) -> void:
	_elapsed_physics_frames += 1
	_elapsed_time += delta

	for state: State in _active_superstates:
		state._on_physics_tick(delta)
	_current_state._on_physics_tick(delta)

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

	if _current_state.runtime > 0.0 and _elapsed_time >= _current_state.runtime:
		_notify_done(false)

	var max_cascade: int = 8
	while max_cascade > 0:
		var before: State = _current_state
		_evaluate_transitions()
		if _current_state == before or _pending_transition:
			break
		if not _immediate_out.get(_current_uuid, false):
			break
		max_cascade -= 1


# Propagates the resolved root node, sprite, and animation player to all states and transitions.
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


# Precomputes state identity, flattened aliases, and priority-sorted outgoing adjacency
# so per-frame transition evaluation is O(out-degree) with no scanning or allocation.
func _build_tables() -> void:
	_uuid_of_state.clear()
	_alias_target.clear()
	_out_transitions.clear()
	_transition_target.clear()
	_immediate_out.clear()

	for uuid: StringName in __states:
		var s: State = __states.get(uuid) as State
		if s:
			_uuid_of_state[s] = uuid

	for alias_uuid: StringName in __aliases:
		var data: Dictionary = __aliases.get(alias_uuid, {})
		_alias_target[alias_uuid] = StringName(data.get("original_uuid", ""))

	for tid: StringName in __transitions:
		var t: StateTransition = __transitions.get(tid) as StateTransition
		if not t:
			continue
		var from_uuid: StringName = _resolve_uuid(StringName(t.__from_uuid))
		if not _out_transitions.has(from_uuid):
			_out_transitions[from_uuid] = []
		_out_transitions.get(from_uuid).append(t)
		_transition_target[t] = _resolve_state(StringName(t.__to_uuid))

	for uuid: StringName in _out_transitions:
		var list: Array = _out_transitions.get(uuid)
		list.sort_custom(_sort_priority_desc)
		for t: StateTransition in list:
			if t.check_immediately:
				_immediate_out[uuid] = true
				break


func _sort_priority_desc(a: StateTransition, b: StateTransition) -> bool:
	return a.priority > b.priority


# Fires the first eligible outgoing transition from the current state (or an always-checking
# superstate), honoring priority, min_active_frames, and the state's veto gates.
func _evaluate_transitions() -> void:
	if _elapsed_physics_frames < _current_state.min_active_frames:
		return
	if not _current_state._can_exit():
		return

	for t: StateTransition in _gather_candidates():
		if not _should_fire(t, []):
			continue
		var target: State = _transition_target.get(t)
		if not target or not target._can_enter():
			continue
		if t.transition_time > 0.0:
			_pending_transition = t
			_pending_transition_target = target
			_pending_transition_timer = t.transition_time
			return
		_transition_to(t, target)
		return


# Returns the priority-sorted transitions eligible to fire from the current stack. Fast-paths
# the common case (no always-checking superstate) to the precomputed, allocation-free list.
func _gather_candidates() -> Array:
	var from_current: Array = _out_transitions.get(_current_uuid, [])
	if not _has_always_superstate:
		return from_current

	var candidates: Array[StateTransition] = []
	for t: StateTransition in from_current:
		candidates.append(t)
	for superstate: State in _active_superstates:
		if not superstate.always_transition:
			continue
		var suid: StringName = _uuid_of_state.get(superstate, &"")
		for t: StateTransition in _out_transitions.get(suid, []):
			var target: State = _transition_target.get(t)
			if target and not _is_state_in_stack(target):
				candidates.append(t)
	candidates.sort_custom(_sort_priority_desc)
	return candidates


# Evaluates whether a transition's mode conditions and target passthrough chain are satisfied.
func _should_fire(t: StateTransition, visited: Array[State]) -> bool:
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

	var target: State = _transition_target.get(t)
	if target and target.is_passthrough:
		return _has_outgoing_transition_from(target, visited)
	return true


# Checks if a passthrough state has a fireable outgoing transition, guarding against cycles.
func _has_outgoing_transition_from(state: State, visited: Array[State]) -> bool:
	if state in visited:
		return false
	visited.append(state)
	if not state._pre_entered:
		state._pre_enter()
		state._pre_entered = true

	var uuid: StringName = _uuid_of_state.get(state, &"")
	for t: StateTransition in _out_transitions.get(uuid, []):
		if _should_fire(t, visited):
			return true
	return false


# Executes the full exit/enter lifecycle, updates the active stack, and emits state_changed.
func _transition_to(t: StateTransition, target: State) -> void:
	_last_transition = t
	_next_state = target
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

	if t:
		t._on_before_transition()
	_current_state.__collision_exit()
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

	_set_active_stack(target, new_superstates)
	_elapsed_time = 0.0
	_elapsed_frames = 0
	_elapsed_physics_frames = 0

	for s: State in entering:
		s._on_enter()
	target._on_enter()
	target.__sprite_enter()
	target.__animation_enter()
	target.__collision_enter()

	_next_state = null
	if t:
		t._on_after_transition()
	state_changed.emit(from, target)


# Sets the initial state, builds the superstate stack, and fires enter callbacks once.
func _enter_state(state: State) -> void:
	var superstates: Array[State] = _collect_superstates(state)
	_set_active_stack(state, superstates)
	_elapsed_time = 0.0
	_elapsed_frames = 0
	_elapsed_physics_frames = 0
	_running = true

	for s: State in superstates:
		if not s._pre_entered:
			s._pre_enter()
		s._pre_entered = false
		s._on_enter()
	if not state._pre_entered:
		state._pre_enter()
	state._pre_entered = false
	state._on_enter()
	state.__sprite_enter()
	state.__animation_enter()
	state.__collision_enter()


func _set_active_stack(current: State, superstates: Array[State]) -> void:
	_current_state = current
	_current_uuid = _uuid_of_state.get(current, &"")
	_active_superstates = superstates
	_has_always_superstate = false
	for s: State in superstates:
		if s.always_transition:
			_has_always_superstate = true
			break


# Walks the superstate chain of a state and returns an ordered array from outermost to innermost.
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


# Returns true if the given state is either the current state or anywhere in the active superstate stack.
func _is_state_in_stack(state: State) -> bool:
	if state == _current_state:
		return true
	return state in _active_superstates


func _resolve_uuid(uuid: StringName) -> StringName:
	return _alias_target.get(uuid, uuid)


func _resolve_state(uuid: StringName) -> State:
	return __states.get(_resolve_uuid(uuid)) as State


func _resolve_entry_state() -> State:
	if __has_entry and not __entry_target_uuid.is_empty():
		var entry_state: State = __states.get(__entry_target_uuid) as State
		if entry_state:
			return entry_state
	return initial_state


# Looks up a state by its editor name, accepting both snake_case and original casing.
func _resolve_state_name(state_name: String) -> State:
	for uuid: StringName in __states:
		var state: State = __states.get(uuid) as State
		if not state:
			continue
		if state.__editor_name == state_name.to_snake_case() or state.__editor_name == state_name:
			return state
	return null


# Sets the done flag so WAIT_UNTIL_DONE transitions can fire; forced=true bypasses condition checks.
func _notify_done(forced: bool) -> void:
	if forced:
		_done_forced = true
	else:
		_done_requested = true


## Stores an input buffer for the given duration in seconds (default 0.1).
## Call this just before an action to allow a brief window where the next state
## can consume it via [method consume_state_buffer].
## [br][br]
## [param amount] Duration in seconds the buffer remains active.[br]
## [br]
## Returns [code]true[/code] always (convenience for inline use in conditions).
func store_state_buffer(amount: float = 0.1) -> bool:
	_state_buffer = amount
	_can_consume_buffer = false
	return true


## Attempts to consume a pending state buffer. Returns [code]true[/code] if the
## buffer has already elapsed (i.e. the action can proceed immediately), or arms
## consumption so the next [method store_state_buffer] expiry grants it.
## [br][br]
## Returns [code]true[/code] if the buffer is already empty and the action should fire now.
func consume_state_buffer() -> bool:
	_can_consume_buffer = true
	return _state_buffer == 0.0


## Immediately transitions to the state matching [param state_name].
## Bypasses transition conditions. If the machine is not yet running, the state
## is entered directly without an outgoing transition object.
## [br][br]
## [param state_name] The [member State.__editor_name] of the target state (snake_case or original casing).
func change_state(state_name: String) -> void:
	var target: State = _resolve_state_name(state_name)
	if not target:
		push_warning("StateMachine: no state found for '%s'" % state_name)
		return
	if not _running:
		_enter_state(target)
		return
	_transition_to(null, target)


## Fires the first [constant StateTransition.TransitionMode.MANUAL] transition
## from the current state whose label matches [param transition_label].
## [br][br]
## [param transition_label] The label string set on the target [StateTransition].
func trigger(transition_label: String) -> void:
	if not _current_state:
		return
	for t: StateTransition in _out_transitions.get(_current_uuid, []):
		if t.mode != StateTransition.TransitionMode.MANUAL:
			continue
		if t.label == transition_label:
			var target: State = _transition_target.get(t)
			if target:
				_transition_to(t, target)
			return


## Stops the machine, exiting the active state stack and halting all ticks and transitions.
func stop() -> void:
	if not _running or not _current_state:
		return
	_current_state.__collision_exit()
	_current_state.__sprite_exit()
	_current_state.__animation_exit()
	_current_state._on_exit()
	for s: State in _active_superstates:
		s._on_exit()
	_running = false
	_current_state = null
	_current_uuid = &""
	_active_superstates = []
	_pending_transition = null
	_pending_transition_target = null
	_pending_transition_timer = 0.0


## Stops the machine and re-enters the initial (or entry-linked) state from scratch.
func reset() -> void:
	stop()
	var entry_state: State = _resolve_entry_state()
	if entry_state:
		_enter_state(entry_state)


## Returns the currently active leaf [State].
func get_current_state() -> State:
	return _current_state


## Returns a copy of the active superstate stack, ordered from outermost to innermost.
func get_active_superstates() -> Array[State]:
	return _active_superstates.duplicate()


## Returns [code]true[/code] if the state matching [param state_name] is currently
## active - either as the current state or anywhere in the superstate stack.
## [br][br]
## [param state_name] The [member State.__editor_name] of the state to check.
func is_state_active(state_name: String) -> bool:
	var target: State = _resolve_state_name(state_name)
	if not target:
		return false
	return _is_state_in_stack(target)
