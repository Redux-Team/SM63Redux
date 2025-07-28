class_name Component
extends Node

@export var enabled: bool = true:
	set(e):
		if e:
			process_mode = Node.PROCESS_MODE_INHERIT
		else:
			process_mode = Node.PROCESS_MODE_DISABLED
		
		enabled = e

var entity: Entity:
	get():
		return owner as Entity
