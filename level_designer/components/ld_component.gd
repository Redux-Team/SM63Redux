@warning_ignore_start("unused_parameter")
@abstract class_name LDComponent
extends Node

var ignore_input_priority: bool
var _input_overridden: bool = true
var _on_input_overridden: bool = true

## LD-specific method for the ready event. Using this allows the LD component
## to do some internal setup in the background by not overriding [method _ready].
@abstract func _on_ready() -> void
## LD-specific method for input events. Use this when input priority matters,
## otherwise use [method _input] for events that don't rely on priority.

func _on_input(event: InputEvent) -> void:
	_on_input_overridden = false


func _ready() -> void:
	_input(null)
	_on_input(null)
	
	if _input_overridden and not _on_input_overridden:
		push_warning("The input function has been overriden in %s without a _on_input() declaration. Please either use _on_input() instead or declare it with an empty definition." % self)
	
	_on_ready()


func _input(event: InputEvent) -> void:
	_input_overridden = false


func set_input_priority() -> void:
	LD.get_input_handler().set_input_priority(self)


func remove_input_priority() -> void:
	LD.get_input_handler().remove_input_priority(self)


func has_input_priority() -> bool:
	return LD.get_input_handler().has_input_priority(self)
