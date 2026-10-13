extends PropertyWidget

@export var label: Label
@export var line_edit: LineEdit


func _ready() -> void:
	line_edit.text_submitted.connect(_commit)
	line_edit.focus_exited.connect(func() -> void: _commit(line_edit.text))


func _name(widget_name: String) -> void:
	label.text = widget_name


func _value(widget_value: Variant) -> void:
	if not line_edit.has_focus():
		line_edit.text = str(widget_value)
