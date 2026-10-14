extends PropertyWidget

const PICKER_SIZE: int = 120
const HUE_WIDTH: int = 14

@export var label: Label
@export var picker: ColorPickerButton


func _ready() -> void:
	picker.color_changed.connect(_commit)
	var color_picker: ColorPicker = picker.get_picker()
	color_picker.sampler_visible = false
	color_picker.color_modes_visible = false
	color_picker.sliders_visible = false
	color_picker.presets_visible = false
	color_picker.can_add_swatches = false
	color_picker.hex_visible = true
	color_picker.add_theme_constant_override(&"sv_width", PICKER_SIZE)
	color_picker.add_theme_constant_override(&"sv_height", PICKER_SIZE)
	color_picker.add_theme_constant_override(&"h_width", HUE_WIDTH)


func _name(widget_name: String) -> void:
	label.text = widget_name


func _value(widget_value: Variant) -> void:
	picker.color = widget_value
