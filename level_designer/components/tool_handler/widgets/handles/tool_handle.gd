class_name LDToolHandle
extends Control

## One grab point drawn over the viewport. Instanced from tool_handle.tscn by
## [LDToolHandleSet]; never constructed in a tool script. Purely a display node - hit testing
## belongs to the owning [LDToolWidget], which grabs by [member LDToolWidgetStyle.grab_radius]
## rather than by node bounds.

## Keeps a handle grabbable when its style failed to load, matching LDToolHandleSet.FALLBACK_SIZE.
const FALLBACK_GRAB_RADIUS: float = 18.0


@export var _texture: TextureRect


var style: LDToolWidgetStyle:
	set(value):
		style = value
		_refresh()

var state: LDToolWidgetStyle.State = LDToolWidgetStyle.State.NORMAL:
	set(value):
		if state == value:
			return
		state = value
		_refresh()

## Multiplies the style's tint. Used for per-handle shading the style itself cannot express,
## such as the topline tool's on/off edges.
var shade: Color = Color.WHITE:
	set(value):
		if shade == value:
			return
		shade = value
		_refresh()

## Screen-space centre this handle was last placed at, kept so the widget can hit-test without
## reading back through the node's rect.
var screen_center: Vector2 = Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Centres the handle on a screen point at the given size.
func place(center: Vector2, screen_size: Vector2) -> void:
	screen_center = center
	size = screen_size
	position = center - screen_size * 0.5


func get_grab_radius() -> float:
	return style.grab_radius if style else FALLBACK_GRAB_RADIUS


func _refresh() -> void:
	if not _texture:
		return
	if not style:
		_texture.texture = null
		return
	_texture.texture = style.get_texture(state)
	_texture.modulate = style.get_tint(state) * shade
