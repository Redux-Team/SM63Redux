extends PropertyWidget

@export var label: Label
@export var line_edit: LineEdit

var _integer: bool = false


func _ready() -> void:
	line_edit.text_submitted.connect(_commit_text.unbind(1))
	line_edit.focus_exited.connect(_commit_text)


func _name(widget_name: String) -> void:
	label.text = widget_name


func _info(widget_info: Dictionary) -> void:
	_integer = widget_info.get("type") == TYPE_INT


func _value(widget_value: Variant) -> void:
	line_edit.text = str(widget_value) if _integer else String.num(widget_value, 3)


func _commit_text() -> void:
	if line_edit.text.is_valid_float():
		_commit(line_edit.text.to_int() if _integer else line_edit.text.to_float())
	else:
		_value(binding.get_value())
