class_name LDGlassSlider
extends HSlider

## An HSlider whose bitmap grabber is hidden and replaced with a GDSS-styled vector knob,
## so it stays crisp at any viewport scale (bitmap grabbers rasterize blurry in the upscaled
## low-resolution canvas). The base HSlider still drives dragging, value, and range.


const KNOB: int = 16


var _knob: Panel


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var blank: ImageTexture = ImageTexture.create_from_image(Image.create(KNOB, KNOB, false, Image.FORMAT_RGBA8))
	add_theme_icon_override(&"grabber", blank)
	add_theme_icon_override(&"grabber_highlight", blank)
	add_theme_icon_override(&"grabber_disabled", blank)
	_knob = Panel.new()
	_knob.custom_minimum_size = Vector2(KNOB, KNOB)
	_knob.size = Vector2(KNOB, KNOB)
	_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_knob.set_meta(&"gdss_classes", PackedStringArray(["SliderKnob"]))
	add_child(_knob)
	value_changed.connect(_reposition_knob)
	resized.connect(_reposition_knob)
	_reposition_knob()


func _reposition_knob(_value: float = 0.0) -> void:
	if _knob == null:
		return
	var span: float = max_value - min_value
	var ratio: float = (value - min_value) / span if span > 0.0 else 0.0
	_knob.position = Vector2(ratio * (size.x - KNOB), (size.y - KNOB) * 0.5)
