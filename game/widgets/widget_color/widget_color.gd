extends PropertyWidget

@export var label: Label
@export var picker: ColorPickerButton


func _ready() -> void:
	picker.color_changed.connect(_commit)


func _name(widget_name: String) -> void:
	label.text = widget_name


func _value(widget_value: Variant) -> void:
	picker.color = widget_value
