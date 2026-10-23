extends Node2D

@export var key: StringName
@export var format: String = "x%d"
@export var hide_when_zero: bool = true
@export var icon: Texture2D
@export var icon_scale: float = 0.5
@export var font: Font = preload("res://assets/font/pixel_redux_border.fnt")
@export var font_size: int = 16
@export var spacing: float = 1.0

var _object: GameObject
var _text: String = ""


func _ready() -> void:
	_object = GameObject.of(self)
	if _object:
		_object.value_changed.connect(_on_value_changed)
		_on_value_changed(key, _object.get_value(key))


func _draw() -> void:
	var text_size: Vector2 = font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var icon_size: Vector2 = icon.get_size() * icon_scale if icon else Vector2.ZERO
	var width: float = icon_size.x + (spacing if icon else 0.0) + text_size.x
	var left: float = -width * 0.5
	if icon:
		draw_texture_rect(icon, Rect2(Vector2(left, -icon_size.y * 0.5), icon_size), false)
	draw_string(
			font,
			Vector2(
					left + width - text_size.x,
					font.get_ascent(font_size) - text_size.y * 0.5,
			).round(),
			_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
	)


func _on_value_changed(changed: StringName, value: Variant) -> void:
	if changed != key:
		return
	
	visible = not (hide_when_zero and not value)
	_text = format % value
	queue_redraw()
