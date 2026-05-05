#class_name StateMachine
#extends Node
#
#
#signal state_changed(from: StringName, to: StringName)
#signal state_entered(state_name: StringName)
#signal state_exited(state_name: StringName)
#signal state_added(state_name: StringName)
#signal state_removed(state_name: StringName)
#signal transitioned_to_unknown(state_name: StringName)
#
#
#var current_state: State = null
#var previous_state_name: StringName = &""
#
#var _states: Dictionary = {}
#
#
#func _process(delta: float) -> void:
	#if current_state:
		#current_state._on_tick(delta)
#
#
#func _physics_process(delta: float) -> void:
	#if current_state:
		#current_state._on_physics_tick(delta)
#
#
#func _input(event: InputEvent) -> void:
	#if current_state:
		#current_state._on_input(event)
#
#
#func add_state(state: State, state_name: StringName) -> StringName:
	#var resolved: StringName = _resolve_name(state_name)
	#state.name = resolved
	#state.machine = self
	#state.host = get_parent()
	#_states[resolved] = state
	#add_child(state)
	#state_added.emit(resolved)
	#return resolved
#
#
#func remove_state(state_name: StringName) -> void:
	#if not _states.has(state_name):
		#return
	#
	#var state: State = _states[state_name]
	#if current_state == state:
		#_exit_current()
		#current_state = null
	#
	#_states.erase(state_name)
	#state.queue_free()
	#state_removed.emit(state_name)
#
#
#func transition_to(state_name: StringName) -> void:
	#if not _states.has(state_name):
		#transitioned_to_unknown.emit(state_name)
		#return
	#
	#var next: State = _states[state_name]
	#if next == current_state:
		#return
	#
	#var from_name: StringName = _current_state_name()
	#_exit_current()
	#current_state = next
	#current_state._on_enter()
	#state_entered.emit(state_name)
	#state_changed.emit(from_name, state_name)
#
#
#func get_state(state_name: StringName) -> State:
	#return _states.get(state_name, null)
#
#
#func has_state(state_name: StringName) -> bool:
	#return _states.has(state_name)
#
#
#func get_current_state_name() -> StringName:
	#return _current_state_name()
#
#
#func get_all_state_names() -> Array[StringName]:
	#var names: Array[StringName] = []
	#for key: StringName in _states:
		#names.append(key)
	#return names
#
#
#func _exit_current() -> void:
	#if current_state == null:
		#return
	#
	#previous_state_name = _current_state_name()
	#current_state._on_exit()
	#state_exited.emit(previous_state_name)
#
#
#func _current_state_name() -> StringName:
	#if current_state == null:
		#return &""
	#
	#for key: StringName in _states:
		#if _states[key] == current_state:
			#return key
	#
	#return &""
#
#
#func _resolve_name(state_name: StringName) -> StringName:
	#if not _states.has(state_name):
		#return state_name
	#
	#var counter: int = 2
	#var candidate: StringName = StringName(str(state_name) + str(counter))
	#while _states.has(candidate):
		#counter += 1
		#candidate = StringName(str(state_name) + str(counter))
	#
	#return candidate
