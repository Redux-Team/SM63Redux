class_name StateProcess extends Node

var disabled: bool = false:
	set(value):
		if value:
			process_mode = Node.PROCESS_MODE_DISABLED
		else:
			process_mode = Node.PROCESS_MODE_INHERIT

var state_machine: StateMachine

var entity: Entity:
	get():
		return state_machine.entity

var player: Player:
	get():
		if state_machine:
			return state_machine.entity as Player
		elif owner is Player:
			return owner
		else:
			return null

var sprite: AnimatedSprite2D:
	get():
		return state_machine.sprite
