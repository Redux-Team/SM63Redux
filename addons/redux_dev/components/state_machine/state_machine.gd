## Holds and organizes [State] nodes, driving transitions between them.
##
## [StateMachine] is the central runtime controller for a node-based state graph.
## [State] nodes are its descendants; superstate nesting is expressed directly by the scene
## tree, and each [State]'s outgoing [StateTransition] resources live in its
## [member State.transitions] array, checked in order (top = highest priority). The machine
## evaluates transition conditions on the fixed physics clock, manages the superstate stack, and
## dispatches lifecycle callbacks ([method State._on_enter], [method State._on_physics_tick],
## [method State._on_exit], etc.) to active states. [br][br]
## All gameplay logic and transition evaluation run in [method _physics_process] so behavior is
## identical at any render framerate; [method _process] only drives visual, render-rate hooks
## ([method State._sprite_rules] and [method State._on_render_tick]). [br][br]
## This StateMachine does not require the Redux Development Plugin to run, however it is
## recommended to use it in order to [b]edit[/b] everything in the StateMachine.
@icon("uid://c62fk8rmsd0do")
@tool
class_name StateMachine
extends Node


signal state_changed(from: State, to: State)

## The [State] the machine enters on ready.
@export var initial_state: State
@export var root_node: NodePath
@export var sprite: SmartSprite2D
@export var animation_player: AnimationPlayer
## The audio bus a [State]'s SFX plays on when its bus is set to [code]Inherit[/code].
@export var default_sfx_bus: StringName = &"SFX"

var _root_node: Node
var _current_state: State
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
var _all_states: Array[State] = []
var _target_of: Dictionary[StateTransition, State] = {}
var _immediate_out: Dictionary[State, bool] = {}
var _editor_targets: Dictionary[StateTransition, State] = {}
var _editor_paths: Dictionary[State, String] = {}


# resolves the root node, builds lookup tables, and enters the initial state.
func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_watch_states()
		return

	_root_node = get_node_or_null(root_node)
	_build_tables()
	_dispatch_root_node()

	if initial_state:
		_enter_state(initial_state)


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
	_current_state.__sfx_frame_tick()


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
	_current_state.__sfx_interval_tick(delta)

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
		if not _immediate_out.get(_current_state, false):
			break
		max_cascade -= 1


# Collects every descendant State, resolves transition targets, and parses expressions once.
func _build_tables() -> void:
	_all_states.clear()
	_target_of.clear()
	_immediate_out.clear()
	_collect_states(self, _all_states)
	for s: State in _all_states:
		if s.transitions.has(null):
			push_warning("StateMachine: state '%s' has an empty transition element" % s.name)
			var pruned: Array[StateTransition] = []
			for t: StateTransition in s.transitions:
				if t:
					pruned.append(t)
			s.transitions = pruned
		for t: StateTransition in s.transitions:
			var target: State = get_node_or_null(t.target) as State
			if not target:
				push_warning("StateMachine: transition '%s' on '%s' has no valid target ('%s')" % [t.resource_name, s.name, t.target])
			_target_of[t] = target
			t._ensure_parsed()
			if t.check_immediately:
				_immediate_out[s] = true


func _collect_states(node: Node, out: Array[State]) -> void:
	for child: Node in node.get_children():
		if child is State:
			out.append(child)
			_collect_states(child, out)


# Propagates the resolved root node, sprite, and animation player to all states.
func _dispatch_root_node() -> void:
	for s: State in _all_states:
		s.state_machine = self
		s.root_node = _root_node
		s.sprite = sprite
		s.animation_player = animation_player


# Fires the first eligible outgoing transition from the current state (or an always-checking
# superstate), honoring array order, min_active_frames, and the state's veto gates.
func _evaluate_transitions() -> void:
	if _elapsed_physics_frames < _current_state.min_active_frames:
		return
	if not _current_state._can_exit():
		return

	for t: StateTransition in _gather_candidates():
		if not _should_fire(t, []):
			continue
		var target: State = _target_of.get(t)
		if not target or not target._can_enter():
			continue
		if t.min_delay > 0.0:
			_pending_transition = t
			_pending_transition_target = target
			_pending_transition_timer = t.min_delay
			return
		_transition_to(t, target)
		return


# Returns the transitions eligible to fire from the current stack, in evaluation order:
# the current state's array top-to-bottom, then always-checking superstates outermost-first.
# Fast-paths the common case (no always-checking superstate) to the allocation-free array.
func _gather_candidates() -> Array:
	if not _has_always_superstate:
		return _current_state.transitions

	var candidates: Array[StateTransition] = []
	for t: StateTransition in _current_state.transitions:
		candidates.append(t)
	for superstate: State in _active_superstates:
		if not superstate.always_transition:
			continue
		for t: StateTransition in superstate.transitions:
			var target: State = _target_of.get(t)
			if target and not _is_state_in_stack(target):
				candidates.append(t)
	return candidates


# Evaluates whether a transition's mode conditions and target passthrough chain are satisfied.
func _should_fire(t: StateTransition, visited: Array[State]) -> bool:
	match t.mode:
		StateTransition.TransitionMode.AUTO:
			if not t._should_transition(self):
				return false
		StateTransition.TransitionMode.WAIT_UNTIL_DONE:
			if not _done_forced and not (_done_requested and t._should_transition(self)):
				return false
		StateTransition.TransitionMode.WAIT_UNTIL_EXPRESSION:
			if not t._evaluate_expression(_root_node) or not t._should_transition(self):
				return false

	var target: State = _target_of.get(t)
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

	for t: StateTransition in state.transitions:
		if _should_fire(t, visited):
			return true
	return false


# Executes the full exit/enter lifecycle, updates the active stack, and emits state_changed.
func _transition_to(t: StateTransition, target: State) -> void:
	_pending_transition = null
	_pending_transition_target = null
	_pending_transition_timer = 0.0
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
		t._on_before_transition(self)
	_current_state.__collision_exit()
	_current_state.__sprite_exit()
	_current_state.__animation_exit()
	_current_state.__sfx_exit()

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
	target.__sfx_enter()

	_next_state = null
	if t:
		t._on_after_transition(self)
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
	state.__sfx_enter()


func _set_active_stack(current: State, superstates: Array[State]) -> void:
	_current_state = current
	_active_superstates = superstates
	_has_always_superstate = false
	for s: State in superstates:
		if s.always_transition:
			_has_always_superstate = true
			break


# Walks the scene-tree parent chain and returns the state's superstates, outermost first.
func _collect_superstates(state: State) -> Array[State]:
	var result: Array[State] = []
	var parent: Node = state.get_parent()
	while parent is State:
		result.push_front(parent as State)
		parent = parent.get_parent()
	return result


# Returns true if the given state is either the current state or anywhere in the active superstate stack.
func _is_state_in_stack(state: State) -> bool:
	if state == _current_state:
		return true
	return state in _active_superstates


# Looks up a state by its identity name, accepting both snake_case and the raw node name.
func _resolve_state_name(state_name: String) -> State:
	var snake: String = state_name.to_snake_case()
	for s: State in _all_states:
		if s.get_internal_name() == snake or String(s.name) == state_name:
			return s
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
## [param state_name] The identity name of the target state (snake_case or the raw node name).
func change_state(state_name: String) -> void:
	var target: State = _resolve_state_name(state_name)
	if not target:
		push_warning("StateMachine: no state found for '%s'" % state_name)
		return
	if not _running:
		_enter_state(target)
		return
	_transition_to(null, target)


## Returns the resolved root node this machine drives.
func get_root() -> Node:
	return _root_node


## Stops the machine, exiting the active state stack and halting all ticks and transitions.
func stop() -> void:
	if not _running or not _current_state:
		return
	_current_state.__collision_exit()
	_current_state.__sprite_exit()
	_current_state.__animation_exit()
	_current_state._stop_tracked_sfx()
	_current_state._on_exit()
	for s: State in _active_superstates:
		s._on_exit()
	_running = false
	_current_state = null
	_active_superstates = []
	_pending_transition = null
	_pending_transition_target = null
	_pending_transition_timer = 0.0


## Stops the machine and re-enters the initial state from scratch.
func reset() -> void:
	stop()
	if initial_state:
		_enter_state(initial_state)


## Returns the currently active leaf [State].
func get_current_state() -> State:
	return _current_state


## Returns a copy of the active superstate stack, ordered from outermost to innermost.
func get_active_superstates() -> Array[State]:
	return _active_superstates.duplicate()


## Returns [code]true[/code] if the state matching [param state_name] is currently
## active - either as the current state or anywhere in the superstate stack.
## [br][br]
## [param state_name] The identity name of the state to check.
func is_state_active(state_name: String) -> bool:
	var target: State = _resolve_state_name(state_name)
	if not target:
		return false
	return _is_state_in_stack(target)


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
	var states: Array[State] = []
	_collect_states(self, states)
	for s: State in states:
		for t: StateTransition in s.transitions:
			if not t:
				warnings.append("State '%s' has an empty transition element." % s.name)
			elif not get_node_or_null(t.target) is State:
				warnings.append("Transition '%s' on state '%s' does not resolve ('%s')." % [t.resource_name, s.name, t.target])
	return warnings


func _editor_watch_states() -> void:
	_editor_targets.clear()
	_editor_paths.clear()
	var states: Array[State] = []
	_collect_states(self, states)
	for s: State in states:
		_editor_paths[s] = String(get_path_to(s))
		for t: StateTransition in s.transitions:
			if not t:
				continue
			var target: State = get_node_or_null(t.target) as State
			if target:
				_editor_targets[t] = target
		if not s.renamed.is_connected(_on_editor_state_renamed):
			s.renamed.connect(_on_editor_state_renamed)
	update_configuration_warnings()


func _on_editor_state_renamed() -> void:
	for t: StateTransition in _editor_targets:
		var target: State = _editor_targets.get(t)
		if is_instance_valid(target) and target.is_inside_tree():
			t.target = get_path_to(target)
	var rekeys: Dictionary = {}
	for s: State in _editor_paths:
		if not is_instance_valid(s) or not s.is_inside_tree():
			continue
		var current: String = String(get_path_to(s))
		if _editor_paths.get(s) != current:
			rekeys[_editor_paths.get(s)] = current
			_editor_paths[s] = current
	if not rekeys.is_empty():
		_editor_rekey_sidecar(rekeys)
	update_configuration_warnings()


func _editor_map_rel(rel: String, rekeys: Dictionary) -> String:
	if rekeys.has(rel):
		return String(rekeys.get(rel))
	for old: Variant in rekeys:
		if rel.begins_with(String(old) + "/"):
			return String(rekeys.get(old)) + rel.substr(String(old).length())
	return rel


func _editor_rekey_sidecar(rekeys: Dictionary) -> void:
	var root: Node = owner if owner else self
	var scene_path: String = root.scene_file_path
	if scene_path.is_empty():
		return
	var path: String = scene_path + ".redux-layout.json"
	if not FileAccess.file_exists(path):
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return
	var data: Dictionary = parsed
	var states: Dictionary = data.get("states", {}) as Dictionary
	var new_states: Dictionary = {}
	for key: Variant in states:
		new_states[_editor_map_rel(String(key), rekeys)] = states.get(key)
	data["states"] = new_states
	var aliases: Dictionary = data.get("aliases", {}) as Dictionary
	for alias_id: Variant in aliases:
		var entry: Variant = aliases.get(alias_id)
		if entry is Dictionary:
			var alias: Dictionary = entry
			alias["state"] = _editor_map_rel(String(alias.get("state", "")), rekeys)
	var routes: Dictionary = data.get("routes", {}) as Dictionary
	var new_routes: Dictionary = {}
	for key: Variant in routes:
		var from_rel: String = _editor_map_rel(String(key).get_slice(" -> ", 0), rekeys)
		var to_rel: String = _editor_map_rel(String(key).get_slice(" -> ", 1), rekeys)
		new_routes["%s -> %s" % [from_rel, to_rel]] = routes.get(key)
	data["routes"] = new_routes
	var out: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not out:
		return
	out.store_string(JSON.stringify(data, "\t"))
	out.close()
