extends PropertyWidget

@export var label: Label
@export var x_edit: LineEdit
@export var y_edit: LineEdit


func _ready() -> void:
	for edit: LineEdit in [x_edit, y_edit]:
		edit.text_submitted.connect(_commit_text.unbind(1))
		edit.focus_exited.connect(_commit_text)


func _name(widget_name: String) -> void:
	label.text = widget_name


func _value(widget_value: Variant) -> void:
	var vector: Vector2 = widget_value
	x_edit.text = String.num(vector.x, 3)
	y_edit.text = String.num(vector.y, 3)


func _commit_text() -> void:
	if x_edit.text.is_valid_float() and y_edit.text.is_valid_float():
		_commit(Vector2(x_edit.text.to_float(), y_edit.text.to_float()))
	else:
		_value(binding.get_value())
