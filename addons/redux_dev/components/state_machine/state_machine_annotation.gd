@tool
class_name EditorStateMachineAnnotation
extends GraphElement

@export var label: Label

var uuid: String = ""
var text: String = "":
	set(value):
		text = value
		if label:
			label.text = value


func _ready() -> void:
	label.text = text
