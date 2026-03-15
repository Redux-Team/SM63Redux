class_name LDIntWidget
extends LDPropertyWidget


@export var property_label: Label
@export var spin_box: SpinBox
@export var reset_button: Button


func _ready() -> void:
	spin_box.rounded = true
	spin_box.step = 1.0
	spin_box.value_changed.connect(func(val: float) -> void:
		_update_reset_button(int(val))
		value_changed.emit(_key, int(val))
	)
	reset_button.pressed.connect(func() -> void:
		value_changed.emit(_key, _default_value)
	)


func _set_label(text: String) -> void:
	if property_label:
		property_label.text = text


func _set_value(value: Variant) -> void:
	if not spin_box:
		return
	spin_box.set_value_no_signal(float(value) if value != null else 0.0)
	_update_reset_button(value)


func _set_step(step: float) -> void:
	if spin_box:
		spin_box.step = step


func _set_arrow_step(step: float) -> void:
	if spin_box:
		spin_box.custom_arrow_step = step


func _update_reset_button(current_value: Variant) -> void:
	if not reset_button:
		return
	reset_button.visible = int(current_value) != int(_default_value) if current_value != null else false


func _on_property_applied(value: Variant) -> void:
	if not spin_box:
		return
	spin_box.set_value_no_signal(float(value) if value != null else 0.0)
	_update_reset_button(value)
