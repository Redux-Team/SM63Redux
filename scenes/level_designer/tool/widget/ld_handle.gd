class_name LDHandle
extends RefCounted

const EASE_HALFLIFE: float = 0.04

var key: Variant
var world: Vector2
var style: LDHandleStyle
var cursor: Control.CursorShape = Control.CURSOR_POINTING_HAND
var tint: Color = Color.WHITE
var angle: float = 0.0
var enabled: bool = true
var alive: bool = true
var _scale: float = 1.0
var _box: StyleBoxFlat


func _init(handle_key: Variant, handle_style: LDHandleStyle) -> void:
	key = handle_key
	style = handle_style


func get_state(hovered: bool, pressed: bool) -> LDHandleStyle.HandleState:
	if not enabled:
		return LDHandleStyle.HandleState.DISABLED
	if pressed:
		return LDHandleStyle.HandleState.PRESSED
	if hovered:
		return LDHandleStyle.HandleState.HOVER
	
	return LDHandleStyle.HandleState.NORMAL


func draw(canvas: CanvasItem, screen: Vector2, state: LDHandleStyle.HandleState, delta: float) -> void:
	var target: float = style.get_scale(state)
	_scale = Motion.damp(_scale, target, EASE_HALFLIFE, delta) if Settings.ui.animations.current_value else target
	var half: Vector2 = style.size * _scale
	var texture: Texture2D = style.get_texture(state)
	canvas.draw_set_transform(screen, angle)
	if texture:
		canvas.draw_texture_rect(texture, Rect2(-half, half * 2.0), false, tint)
	else:
		_draw_shape(canvas, half, style.get_fill(state) * tint, style.get_outline(state) * Color(1.0, 1.0, 1.0, tint.a))
	canvas.draw_set_transform(Vector2.ZERO)


func _draw_shape(canvas: CanvasItem, half: Vector2, fill: Color, outline: Color) -> void:
	match style.shape:
		LDHandleStyle.Shape.CIRCLE:
			canvas.draw_circle(Vector2.ZERO, half.x + style.outline_width * 0.5, outline)
			canvas.draw_circle(Vector2.ZERO, half.x - style.outline_width * 0.5, fill)
		LDHandleStyle.Shape.DIAMOND:
			var outer: PackedVector2Array = _diamond(half + Vector2.ONE * style.outline_width * 0.7)
			canvas.draw_colored_polygon(outer, outline)
			canvas.draw_colored_polygon(_diamond(half - Vector2.ONE * style.outline_width * 0.7), fill)
		_:
			if _box == null:
				_box = StyleBoxFlat.new()
				_box.set_border_width_all(int(style.outline_width))
				_box.set_corner_radius_all(int(style.corner_radius))
			_box.bg_color = fill
			_box.border_color = outline
			_box.draw(canvas.get_canvas_item(), Rect2(-half, half * 2.0))


static func _diamond(half: Vector2) -> PackedVector2Array:
	return PackedVector2Array([Vector2(0.0, -half.y), Vector2(half.x, 0.0), Vector2(0.0, half.y), Vector2(-half.x, 0.0)])
