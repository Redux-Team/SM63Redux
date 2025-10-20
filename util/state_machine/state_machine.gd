class_name StateMachine
extends AnimationTree


signal state_changed(from_state: StringName, to_state: StringName)
signal machine_ended


@export var entity: Entity
@export var sprite: AnimatedSprite2D
@export var states: Dictionary[StringName, State]
@export var processes: Array[StateProcess]


var animation_player: AnimationPlayer:
	get():
		return get_node(anim_player)
var current_state: State
var playback: AnimationNodeStateMachinePlayback
var last_animation_node: StringName
var active_animations: Array[AnimationChain] = []


func _ready() -> void:
	playback = get(&"parameters/playback")
	_initialize_states()
	_initialize_processes()
	
	if sprite:
		sprite.animation_finished.connect(_on_sprite_animation_finished)
		sprite.animation_looped.connect(_on_sprite_animation_looped)


func _process(_delta: float) -> void:
	_check_animation_transition()


func _physics_process(_delta: float) -> void:
	# this prevents false positives when switching states
	await get_tree().physics_frame
	if current_state and current_state.assertions_enabled and current_state.assertions_run_on_process:
		current_state._assertions_check.call_deferred("physics_process")



func change_state(state_name: StringName) -> void:
	var new_state: State = states.get(state_name)
	if not new_state:
		push_warning("State '%s' not found" % state_name)
		return

	var old_state: State = current_state

	# stop all active animation chains before switching
	for chain in active_animations.duplicate():
		chain.stop()
	
	if current_state:
		current_state._on_exit(state_name)
		if current_state.lock_sprite_flipping:
			if entity is Player:
				entity.lock_flipping = false
		if current_state.assertions_enabled and current_state.assertions_run_on_exit:
			current_state._assertions_check("exit")
		current_state.disable_processing()
	
	animation_player.play(&"RESET")
	current_state = new_state
	current_state.enable_processing()
	current_state._on_enter(old_state.state_name if old_state else &"")
	if current_state.lock_sprite_flipping:
		if entity is Player:
			entity.lock_flipping = true
	if current_state.assertions_enabled and current_state.assertions_run_on_enter:
		current_state._assertions_check("enter")
	current_state._animation_handler()
	playback.start(state_name)
	state_changed.emit(old_state.state_name if old_state else &"", state_name)



func set_condition(condition: StringName, value: bool) -> void:
	set("parameters/conditions/" + condition, value)


func play_animation(animation_name: StringName) -> AnimationChain:
	var chain: AnimationChain = AnimationChain.new(self, animation_name)
	active_animations.append(chain)
	chain.start()
	return chain


func stop_animation_chain(chain: AnimationChain) -> void:
	active_animations.erase(chain)


func _initialize_states(node: Node = self) -> void:
	for child: Node in node.get_children():
		if child is State or child is StateProcess:
			child.state_machine = self
			child.entity = entity
			if entity is Player:
				child.player = entity as Player
			child.sprite = sprite

			if child is State:
				child.disable_processing()
				states[child.name] = child
			else:
				processes.append(child)

		_initialize_states(child)


func _initialize_processes() -> void:
	for process: StateProcess in processes:
		process.state_machine = self


func _check_animation_transition() -> void:
	var current_node: StringName = playback.get_current_node()
	
	if last_animation_node != current_node:
		last_animation_node = current_node
		_handle_animation_change(current_node)


func _handle_animation_change(animation_name: StringName) -> void:
	if animation_name == &"End":
		machine_ended.emit()
		return
	
	change_state(animation_name)


func _on_sprite_animation_finished() -> void:
	for chain: AnimationChain in active_animations:
		chain._on_animation_event()


func _on_sprite_animation_looped() -> void:
	for chain: AnimationChain in active_animations:
		chain._on_animation_event()


class AnimationChain:
	var state_machine: StateMachine
	var current_animation: StringName
	var next_animations: Array[AnimationStep] = []
	var current_step_index: int = 0
	var is_playing: bool = false
	
	
	func _init(sm: StateMachine, animation_name: StringName) -> void:
		state_machine = sm
		current_animation = animation_name
	
	
	func start() -> void:
		is_playing = true
		current_step_index = 0
		_connect_signals()
		_play_current_animation()
	
	
	func then(animation_name: StringName) -> AnimationChain:
		var step: AnimationStep = AnimationStep.new()
		step.animation_name = animation_name
		step.trigger_type = AnimationStep.TriggerType.ON_FINISH
		next_animations.append(step)
		return self
	
	
	func when_condition(condition: StringName, animation_name: StringName) -> AnimationChain:
		var step: AnimationStep = AnimationStep.new()
		step.animation_name = animation_name
		step.trigger_type = AnimationStep.TriggerType.ON_CONDITION
		step.condition = condition
		next_animations.append(step)
		return self
	
	
	func when(predicate: Callable, animation_name: StringName) -> AnimationChain:
		var step: AnimationStep = AnimationStep.new()
		step.animation_name = animation_name
		step.trigger_type = AnimationStep.TriggerType.ON_CALLABLE
		step.predicate = predicate
		next_animations.append(step)
		return self
	
	
	func after(seconds: float, animation_name: StringName) -> AnimationChain:
		var step: AnimationStep = AnimationStep.new()
		step.animation_name = animation_name
		step.trigger_type = AnimationStep.TriggerType.ON_TIMER
		step.timer = seconds
		next_animations.append(step)
		return self
	
	
	func loop_back() -> AnimationChain:
		var step: AnimationStep = AnimationStep.new()
		step.animation_name = current_animation
		step.trigger_type = AnimationStep.TriggerType.ON_FINISH
		next_animations.append(step)
		return self
	
	
	func stop() -> void:
		is_playing = false
		_disconnect_signals()
		state_machine.stop_animation_chain(self)
	
	
	func _connect_signals() -> void:
		if state_machine.sprite:
			if not state_machine.sprite.animation_finished.is_connected(_on_animation_event):
				state_machine.sprite.animation_finished.connect(_on_animation_event)
			if not state_machine.sprite.animation_looped.is_connected(_on_animation_event):
				state_machine.sprite.animation_looped.connect(_on_animation_event)
	
	
	func _disconnect_signals() -> void:
		if state_machine.sprite:
			if state_machine.sprite.animation_finished.is_connected(_on_animation_event):
				state_machine.sprite.animation_finished.disconnect(_on_animation_event)
			if state_machine.sprite.animation_looped.is_connected(_on_animation_event):
				state_machine.sprite.animation_looped.disconnect(_on_animation_event)
	
	
	func _on_animation_event() -> void:
		if not is_playing or current_step_index >= next_animations.size():
			return
		
		var step: AnimationStep = next_animations[current_step_index]
		
		# Check if the trigger condition is met
		var should_advance: bool = false
		
		match step.trigger_type:
			AnimationStep.TriggerType.ON_FINISH:
				should_advance = true
			
			AnimationStep.TriggerType.ON_CONDITION:
				should_advance = state_machine.get("parameters/conditions/" + step.condition)
			
			AnimationStep.TriggerType.ON_CALLABLE:
				should_advance = step.predicate.call()
		
		if should_advance:
			_advance_to_next_step()
	
	
	func _advance_to_next_step() -> void:
		if current_step_index >= next_animations.size():
			return
		
		var step: AnimationStep = next_animations[current_step_index]
		current_animation = step.animation_name
		current_step_index += 1
		_play_current_animation()
	
	
	func _play_current_animation() -> void:
		if not state_machine.sprite:
			return
		
		if state_machine.sprite.sprite_frames.has_animation(current_animation):
			state_machine.sprite.animation = current_animation
			state_machine.sprite.play(current_animation)


class AnimationStep:
	enum TriggerType { ON_FINISH, ON_CONDITION, ON_CALLABLE, ON_TIMER }
	
	var animation_name: StringName
	var trigger_type: TriggerType
	var condition: StringName
	var predicate: Callable
	var timer: float = 0.0
