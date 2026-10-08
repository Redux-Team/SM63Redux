@tool
@abstract class_name BackgroundLayer
extends Resource


enum RepeatMode {
	NONE,
	INDEFINITE_X,
	INDEFINITE_Y,
	INDEFINITE_BOTH,
	CUSTOM
}


@export_group("Layer")
@export_placeholder("(Optional)") var layer_name: String:
	set(ln):
		layer_name = ln
		resource_name = ln
@export var enabled: bool = true:
	set(e):
		enabled = e
		emit_changed()
@export var modulate: Color = Color.WHITE:
	set(m):
		modulate = m
		emit_changed()

@export_subgroup("Motion")
@export var scroll_rate: Vector2 = Vector2.ONE:
	set(sr):
		scroll_rate = sr
		emit_changed()
@export var autoscroll: Vector2:
	set(a):
		autoscroll = a
		emit_changed()
@export var scroll_offset: Vector2:
	set(so):
		scroll_offset = so
		emit_changed()

@export_subgroup("Bounds")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "Bounds") var limited: bool:
	set(l):
		limited = l
		emit_changed()
@export var limit: Rect2:
	set(l):
		limit = l
		emit_changed()


@abstract func _build() -> Node


@abstract func _update(node: Node, visible_rect: Rect2) -> void


func _build_parallax() -> Parallax2D:
	var parallax: Parallax2D = Parallax2D.new()
	parallax.scroll_scale = scroll_rate
	parallax.scroll_offset = scroll_offset
	parallax.autoscroll = autoscroll
	parallax.modulate = modulate
	parallax.visible = enabled
	if limited:
		parallax.limit_begin = limit.position
		parallax.limit_end = limit.end
	return parallax
