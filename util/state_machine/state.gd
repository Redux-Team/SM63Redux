class_name State extends Node

@export var use_parent_process: bool = false


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

var state_machine : StateMachine
var state_name: StringName
var parent: Node:
	get():
		if get_parent() is not State:
			push_warning("State parent should be of type \"State\"")
		
		return get_parent()


func _on_enter(_from: StringName) -> void:
	pass

func _on_exit(_to: StringName) -> void:
	pass


func _enter_tree() -> void:
	await owner.ready
	
	if !state_machine:
		push_error("State created without state machine bind: \"%s\"" % name)
