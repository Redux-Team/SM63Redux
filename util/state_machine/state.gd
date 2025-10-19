class_name State
extends Node

## State to inherit processing/behavior from.
@export var superstate: State
@export_group("Default Sprite Animations")
## Plays sprite animations in sequential order, can be done manually by overriding
## [method _animation_handler] 
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var has_default_animations: bool = false
## The types of damage that the invulnerability does not apply to.
@export var animations: Array[StringName]

var entity: Entity
var player: Player:
	get():
		if entity is Player:
			return entity as Player
		else:
			print_stack()
			push_error("The current entity is not of type \"Player\"")
			return entity
var sprite: AnimatedSprite2D
var state_machine: StateMachine
var state_name: StringName
var parent: Node:
	get():
		if get_parent() is not State:
			push_warning("State parent should be of type \"State\"")
		
		return get_parent()


func disable_processing() -> void:
	set_process(false)
	set_physics_process(false)
	
	if superstate:
		superstate.disable_processing()


func enable_processing() -> void:
	set_process(true)
	set_physics_process(true)
	
	if superstate:
		superstate.enable_processing()


func _on_enter(_from: StringName) -> void:
	pass


func _on_exit(_to: StringName) -> void:
	pass


func _animation_handler() -> void:
	if has_default_animations and not animations.is_empty():
		var chain: StateMachine.AnimationChain = state_machine.play_animation(animations.get(0))
		for i: int in range(animations.size() - 1):
			chain.then(animations.get(i + 1))


func _enter_tree() -> void:
	await owner.ready
	
	if !state_machine:
		push_error("State created without state machine bind: \"%s\"" % name)


func _to_string() -> String:
	return name
