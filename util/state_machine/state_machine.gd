class_name StateMachine extends AnimationTree
## The [CharacterBody2D] node for the actor
@export var entity_body: Entity
## The [AnimatedSprite2D] node for the actor's animations
## If the [member current_state]'s animation name corresponds to an animation on this
## actor, the sprite animation is also played in addition. [br][br]
## This would be used if you want to use sprite-based animations. 
@export var entity_sprite: AnimatedSprite2D
## A list of [StringName]s with their corresponding [State]. Each StringNames must 
## correspond to a node in the AnimationTree in order to be handled by 
## the StateMachine and to use functions like [method set_state].
@export var states: Dictionary[StringName, State]
## A list of nodes which run regardless of the state, unless [param disabled] is true.
## These can be toggled through the [param disabled] variable and also hold a reference to the
## StateMachine
@export var processes: Array[StateProcess]

var current_state: State:
	set(new_state):
		if current_state:
			current_state._on_exit()
			current_state.process_mode = Node.PROCESS_MODE_DISABLED
		
		if new_state:
			new_state.process_mode = Node.PROCESS_MODE_INHERIT
			new_state._on_enter()
		else:
			new_state = null
		current_state = new_state

var animation_player : AnimationPlayer
var playback: AnimationNodeStateMachinePlayback
var last_node: StringName

signal node_changed(last_node: StringName, new_node: StringName)
signal machine_ended

func _ready() -> void:
	playback = get(&"parameters/playback")
	node_changed.connect(on_anim_change)
	
	for state in states: 
		states[state].state_name = state
		states[state].state_machine = self
		if states[state] != current_state:
			states[state].process_mode = Node.PROCESS_MODE_DISABLED
	
	for process in processes:
		process.state_machine = self

func _process(_delta: float) -> void:
	var current_node: StringName = playback.get_current_node()
	if last_node != current_node:
		node_changed.emit(last_node, current_node)
		last_node = current_node

func set_condition(condition: StringName, value: bool):
	set("parameters/conditions/" + condition, value)

func set_state(state: StringName):
	playback.start(state)
	current_state = states.get(state)

func on_anim_change(_old_anim: StringName, new_anim: StringName):
	set_state(new_anim)
	if entity_sprite.sprite_frames.has_animation(new_anim):
		entity_sprite.animation = new_anim
	elif new_anim == &"End":
		machine_ended.emit()
