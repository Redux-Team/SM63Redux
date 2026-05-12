## Holds and organizes [State] resources, driving transitions between them.
##
## [StateMachine] is the central runtime controller for a node-based state graph.
## It owns all [State] and [StateTransition] resources, evaluates transition conditions
## each frame, manages superstate stacks, and dispatches lifecycle callbacks
## ([method State._on_enter], [method State._on_tick], [method State._on_exit], etc.)
## to active states. Audio pooling, sprite rules, and animation hooks are also
## coordinated here. [br][br]
## This StateMachine does not require the Redux Development Plugin to run, however it is
## recommended to use it in order to [b]edit[/b] everything in the StateMachine.
## In addition, it is also highly recommended to edit the states themselves in the dedicated
## panel inside of the development plugin, otherwise scary things might happen..
@icon("uid://c62fk8rmsd0do")
@tool
class_name StateMachine
extends Node


signal state_changed(from: State, to: State)

@export var initial_state: State
@export var root_node: NodePath
@export var sprite: SmartSprite2D
@export var animation_player: AnimationPlayer
@export var sfx_root: Node

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
var _sfx_pool: Dictionary[StringName, Array] = {}
var _sfx_pool_2d: Dictionary[StringName, Array] = {}


# hides __ prefixed properties from the inspector unless SHOW_INTERNAL is set in the development plugin.
func _validate_property(property: Dictionary) -> void:
	if property.name.begins_with("__") and not ReduxPlugin.SHOW_INTERNAL:
		property.usage = PROPERTY_USAGE_NO_EDITOR


# resolves the root node and enters the initial or entry-linked state.
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


# Ticks the active state stack, evaluates transitions, and cascades immediates.
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
		if sfx_root and state.sfx_tick:
			_play_sfx_entry(state.sfx_tick, state)
		if sfx_root and state.sfx_frame and sprite:
			if state.sfx_frame.check_frame_trigger(sprite.get_frame()):
				_play_sfx_entry(state.sfx_frame, state)
	
	_current_state._sprite_rules()
	_current_state._on_tick(delta)
	if sfx_root and _current_state.sfx_tick:
		_play_sfx_entry(_current_state.sfx_tick, _current_state)
	if sfx_root and _current_state.sfx_frame and sprite:
		if _current_state.sfx_frame.check_frame_trigger(sprite.get_frame()):
			_play_sfx_entry(_current_state.sfx_frame, _current_state)
	
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


# Physics tick forwarded to all active states and inactive states.
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


# Forwards input events to all active states in the superstate stack.
func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not _running or not _current_state:
		return
	
	for state: State in _active_superstates:
		state._on_input(event)
	_current_state._on_input(event)


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


# Collects and sorts by priority all outgoing transitions for the current state, then fires the first eligible one.
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


# Returns true if the current state has at least one outgoing transition marked check_immediately.
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


# Evaluates whether a transition's mode conditions and target passthrough chain are satisfied.
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


# Checks if a passthrough state has at least one fireable outgoing transition, pre entering it if needed.
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


# Executes the full exit/enter lifecycle, updates the active stack, and emits state_changed.
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
	target.__collision_enter()
	
	if sfx_root:
		for s: State in exiting:
			if s.sfx_exit:
				_play_sfx_entry(s.sfx_exit, s)
			_handle_sfx_exit(s)
		if from.sfx_exit:
			_play_sfx_entry(from.sfx_exit, from)
		_handle_sfx_exit(from)
		for s: State in entering:
			if s.sfx_enter:
				_play_sfx_entry(s.sfx_enter, s)
		if target.sfx_enter:
			_play_sfx_entry(target.sfx_enter, target)
	
	t._on_after_transition()
	state_changed.emit(from, target)


# Sets the initial state, builds the superstate stack, and fires enter callbacks without a prior transition.
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
	state.__collision_enter()


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
	for s: State in _active_superstates:
		if s == state:
			return true
	return false


# Looks up a state by its editor name, accepting both snake_case and original casing.
func _resolve_state_name(state_name: String) -> State:
	for uuid: StringName in __states:
		var state: State = __states.get(uuid) as State
		if not state:
			continue
		if state.__editor_name == state_name.to_snake_case() or state.__editor_name == state_name:
			return state
	return null


# Resolves and plays a StateSFXEntry through the appropriate flat or 2D audio pool.
func _play_sfx_entry(entry: StateSFXEntry, state: State) -> void:
	if not entry or not entry.playlist or not sfx_root:
		return
	if randf() > entry.chance:
		return
	
	match entry.interrupt_policy:
		StateSFXEntry.InterruptPolicy.CANCEL:
			if _is_pool_playing(entry.pool_id, entry.spatial):
				return
		StateSFXEntry.InterruptPolicy.PLAY_IF_SUPERSTATE_ACTIVE:
			if not _is_state_in_stack(state):
				return
		StateSFXEntry.InterruptPolicy.PLAY_ANYWAY:
			pass
	
	var stream: AudioStream = _pick_stream(entry.playlist)
	if not stream:
		return
	
	var pitch: float = entry._resolve_pitch(_root_node)
	var vol: float = entry._resolve_volume(_root_node)
	var bus: StringName = entry._get_bus_name()
	
	if entry.spatial:
		var player: AudioStreamPlayer2D = _get_pool_2d(entry.pool_id, entry.max_stack)
		player.stream = stream
		player.pitch_scale = pitch
		player.volume_db = vol
		player.bus = bus
		player.play()
	else:
		var player: AudioStreamPlayer = _get_pool_flat(entry.pool_id, entry.max_stack)
		player.stream = stream
		player.pitch_scale = pitch
		player.volume_db = vol
		player.bus = bus
		player.play()


# Picks the next stream from a Playlist according to its play order and repeat settings.
func _pick_stream(playlist: Playlist) -> AudioStream:
	if playlist.tracklist.is_empty():
		return null
	match playlist.play_order:
		Playlist.PlayOrder.RANDOM:
			return playlist.tracklist.pick_random()
		Playlist.PlayOrder.RANDOM_NEW:
			var pick: AudioStream = playlist.tracklist.pick_random()
			var attempts: int = 0
			while pick.get_instance_id() == playlist.last_pick and playlist.tracklist.size() > 1 and attempts < 8:
				pick = playlist.tracklist.pick_random()
				attempts += 1
			playlist.last_pick = pick.get_instance_id()
			return pick
		Playlist.PlayOrder.RANDOM_ONCE:
			if playlist.sfx_pool.size() >= playlist.tracklist.size():
				if not playlist.repeat_list:
					return null
				playlist.sfx_pool.clear()
			for _i: int in playlist.tracklist.size():
				var pick: AudioStream = playlist.tracklist.pick_random()
				var id: int = pick.get_instance_id()
				if not playlist.sfx_pool.has(id) and id != playlist.last_pick:
					playlist.sfx_pool.append(id)
					playlist.last_pick = id
					return pick
		Playlist.PlayOrder.SEQUENTIAL:
			if playlist.sfx_pool.size() >= playlist.tracklist.size():
				if not playlist.repeat_list:
					return null
				playlist.sfx_pool.clear()
			var pick: AudioStream = playlist.tracklist[playlist.sfx_pool.size()]
			playlist.sfx_pool.append(0)
			return pick
	return null


# Returns an idle or newly created AudioStreamPlayer from the flat pool for the given pool_id.
func _get_pool_flat(pool_id: StringName, max_stack: int) -> AudioStreamPlayer:
	if not _sfx_pool.has(pool_id):
		_sfx_pool[pool_id] = []
	var pool: Array = _sfx_pool[pool_id]
	for player: AudioStreamPlayer in pool:
		if not player.playing:
			return player
	if pool.size() < max_stack:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		sfx_root.add_child(player)
		pool.append(player)
		return player
	return pool[0]


# Returns an idle or newly created AudioStreamPlayer2D from the spatial pool for the given pool_id.
func _get_pool_2d(pool_id: StringName, max_stack: int) -> AudioStreamPlayer2D:
	if not _sfx_pool_2d.has(pool_id):
		_sfx_pool_2d[pool_id] = []
	var pool: Array = _sfx_pool_2d[pool_id]
	for player: AudioStreamPlayer2D in pool:
		if not player.playing:
			return player
	if pool.size() < max_stack:
		var player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
		sfx_root.add_child(player)
		pool.append(player)
		return player
	return pool[0]


# Returns true if any player in the given pool is currently playing.
func _is_pool_playing(pool_id: StringName, spatial: bool) -> bool:
	var pool: Array = _sfx_pool_2d[pool_id] if spatial else _sfx_pool[pool_id]
	if not _sfx_pool_2d.has(pool_id) if spatial else not _sfx_pool.has(pool_id):
		return false
	for player: Object in pool:
		if (player as AudioStreamPlayer2D).playing if spatial else (player as AudioStreamPlayer).playing:
			return true
	return false


# Stops or frees audio pools for all SFX entries belonging to a state that is exiting.
func _handle_sfx_exit(state: State) -> void:
	for entry: StateSFXEntry in [state.sfx_enter, state.sfx_exit, state.sfx_tick, state.sfx_frame]:
		if not entry:
			continue
		if entry.free_pool_on_exit:
			_free_pool_entry(entry.pool_id, entry.spatial)
		elif entry.stop_on_exit:
			_stop_pool_entry(entry.pool_id, entry.spatial)


# Stops all players in the given pool without freeing them.
func _stop_pool_entry(pool_id: StringName, spatial: bool) -> void:
	if spatial:
		if not _sfx_pool_2d.has(pool_id):
			return
		for player: AudioStreamPlayer2D in _sfx_pool_2d[pool_id]:
			player.stop()
	else:
		if not _sfx_pool.has(pool_id):
			return
		for player: AudioStreamPlayer in _sfx_pool[pool_id]:
			player.stop()


# queue_frees all players in the given pool and removes the pool entry.
func _free_pool_entry(pool_id: StringName, spatial: bool) -> void:
	if spatial:
		if not _sfx_pool_2d.has(pool_id):
			return
		for player: AudioStreamPlayer2D in _sfx_pool_2d[pool_id]:
			player.queue_free()
		_sfx_pool_2d.erase(pool_id)
	else:
		if not _sfx_pool.has(pool_id):
			return
		for player: AudioStreamPlayer in _sfx_pool[pool_id]:
			player.queue_free()
		_sfx_pool.erase(pool_id)


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
	var t: StateTransition = StateTransition.new()
	t.__from_uuid = _current_state.__editor_uuid if _current_state else StringName("")
	t.__to_uuid = target.__editor_uuid
	_transition_to(t, target)


## Fires the first [constant StateTransition.TransitionMode.MANUAL] transition
## from the current state whose label matches [param transition_label].
## [br][br]
## [param transition_label] The label string set on the target [StateTransition].
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
