@tool
class_name EditorStateMachineAnnotation
extends GraphElement

@export var line_edit: LineEdit

var uuid: String = ""
var text: String = "":
	set(value):
		text = value
		if line_edit:
			line_edit.text = value


func _ready() -> void:
	line_edit.text = text
