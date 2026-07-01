class_name LDStringWidget
extends LDPropertyWidget


@export var property_label: Label
@export var line_edit: LineEdit
@export var reset_button: Button


func _ready() -> void:
	line_edit.text_changed.connect(func(text: String) -> void:
		_update_reset_button(text)
		value_changed.emit(_key, text)
	)
	reset_button.pressed.connect(func() -> void:
		value_changed.emit(_key, _default_value)
	)


func _set_label(text: String) -> void:
	if property_label:
		property_label.text = text


func _set_value(value: Variant) -> void:
	if line_edit:
		line_edit.text = str(value) if value != null else ""
		_update_reset_button(value)


func _update_reset_button(current_value: Variant) -> void:
	if reset_button:
		reset_button.visible = str(current_value) != str(_default_value) if current_value != null else false


func _on_property_applied(value: Variant) -> void:
	if line_edit:
		line_edit.text = str(value) if value != null else ""
		_update_reset_button(value)
