class_name LDVector2Widget
extends LDPropertyWidget


@export var property_label: Label
@export var spin_box_x: SpinBox
@export var spin_box_y: SpinBox
@export var x_label: Label
@export var y_label: Label
@export var reset_button: Button


func _ready() -> void:
	spin_box_x.value_changed.connect(func(_val: float) -> void:
		value_changed.emit(_key, Vector2(spin_box_x.value, spin_box_y.value))
	)
	spin_box_y.value_changed.connect(func(_val: float) -> void:
		value_changed.emit(_key, Vector2(spin_box_x.value, spin_box_y.value))
	)
	reset_button.pressed.connect(func() -> void:
		value_changed.emit(_key, _default_value)
	)


func _set_label(text: String) -> void:
	if property_label:
		property_label.text = text


func _set_value(value: Variant) -> void:
	if not spin_box_x or not spin_box_y:
		return
	var v: Vector2 = value if value != null else Vector2.ZERO
	spin_box_x.set_value_no_signal(v.x)
	spin_box_y.set_value_no_signal(v.y)
	_update_reset_button(v)


func _update_reset_button(current_value: Variant) -> void:
	if not reset_button:
		return
	reset_button.visible = current_value != _default_value


func _hide_reset() -> void:
	if reset_button:
		reset_button.hide()


func set_component_names(x: String, y: String) -> void:
	x_label.text = x
	y_label.text = y


func _on_property_applied(value: Variant) -> void:
	_set_value(value)
