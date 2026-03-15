class_name LDBooleanWidget
extends LDPropertyWidget


@export var property_label: Label
@export var check_box: CheckBox
@export var reset_button: Button


func _ready() -> void:
	check_box.toggled.connect(func(val: bool) -> void:
		value_changed.emit(_key, val)
	)
	reset_button.pressed.connect(func() -> void:
		value_changed.emit(_key, _default_value)
	)


func _set_label(text: String) -> void:
	if property_label:
		property_label.text = text


func _set_value(value: Variant) -> void:
	if not check_box:
		return
	var v: bool = value if value != null else false
	check_box.set_pressed_no_signal(v)
	_update_reset_button(v)


func _update_reset_button(current_value: Variant) -> void:
	if not reset_button:
		return
	reset_button.visible = current_value != _default_value


func _hide_reset() -> void:
	if reset_button:
		reset_button.hide()


func _on_property_applied(value: Variant) -> void:
	_set_value(value)
