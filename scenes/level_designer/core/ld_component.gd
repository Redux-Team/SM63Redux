@abstract class_name LDComponent
extends Node

@export var enabled: bool = true

var handler: LDHandler
var editor: LD:
	get:
		return handler.editor


func _setup() -> void:
	pass
