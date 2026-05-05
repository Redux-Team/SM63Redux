@icon("uid://btg8b714itoxv")
class_name State
extends Node

@export var _editor_name: StringName # This must be unique, serves as state name
@export var _editor_position: Vector2 # Position in editor
@export var _editor_uuid: StringName
@export var _editor_superstate_uuid: StringName

var state_machine: StateMachine
var root_node: Node
var entity: Entity:
	get:
		if root_node is Entity:
			return root_node as Entity
		else:
			print_debug("root_node passed as Entity when type does not match!")
			return null
var player: Player:
	get:
		if root_node is Player:
			return root_node as Player
		else:
			print_debug("root_node passed as Player when type does not match!")
			return null


## Returns the time this state has been active for, in seconds.
func get_elapsed_time() -> float:
	return 0.0

## Returns the amount of process frames this state has been active for.
func get_elapsed_frames() -> int:
	return 0

## Returns the amount of physics frames this state has been active for.
func get_elapsed_physics_frames() -> int:
	return 0

## Returns the last active state before this one.
func get_last_state() -> State:
	return null

## Only valid for [method _on_exit] and [method _post_exit]. Will return the next
## state that the StateMachine is transitioning to.
func get_next_state() -> State:
	return null

## Returns the root superstate that is being ran on the StateMachine, if this node
## is the root, null is returned.
func get_superstate_root() -> State:
	return null

## Returns the parent superstate that is being ran on the StateMachine, if this node
## has no superstate parent, null is returned.
func get_superstate_parent() -> State:
	return null

## Returns whether this state is currently active in the state machine or not. This
## includes whether it is being ran as a superstate or not.
func is_active() -> bool:
	return false

## Returns whether this state is the primary active state in the state machine.
func is_primary_active() -> bool:
	return false

## Defines whether the state machine can transition to this state. If false is
## returned even when the transition case is true, it will not go through and
## it will remain on the previous state, no exit methods from this state will be called.
func _can_enter() -> bool:
	return true

## Defines whether the state machine can transition from this state. If false is
## returned even when the transition case is true, it will not go through and
## it will remain on this state, no exit methods from this state will be called.
func _can_exit() -> bool:
	return true

## Called every process frame, semantically used to handle sprite behavior
func _sprite_rules() -> void:
	pass

## Called before the state is entered, just after [method _on_exit] 
## is called on the previous state. Useful for ensuring behavior before any
## tick method is called.
func _pre_enter() -> void:
	pass

## Called after [method _post_exit] is called on the previous state and this
## state has officially been entered.
func _on_enter() -> void:
	pass

## Similar to [method _process], but will only be called when the state
## is active. You may call [method _process] for behavior that must be ran
## regardless of which state is active.
func _on_tick(delta: float) -> void:
	pass

## Similar to [method _on_tick], but will only be called when the state
## is inactive.
func _on_tick_inactive(delta: float) -> void:
	pass

## Similar to [method _physics_process], but will only be called when the state
## is active. You may call [method _physics_process] for behavior that must be ran
## regardless of which state is active.
func _on_physics_tick(delta: float) -> void:
	pass

## Similar to [method _on_physics_tick], but will only be called when the state
## is inactive.
func _on_physics_tick_inactive(delta: float) -> void:
	pass

## Similar to [method _input], but will only be called when the state
## is active. You may call [method _input] for behavior that must be ran
## regardless of which state is active.
func _on_input(event: InputEvent) -> void:
	pass

## Called before exiting the state and before [method _pre_enter] is called on the
## next state.
func _on_exit() -> void:
	pass

## Called after completely exiting the state and before [method _on_enter] is
## called on the next state.
func _post_exit() -> void:
	pass
