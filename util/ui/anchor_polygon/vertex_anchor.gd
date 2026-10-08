@tool
## A vertex for an [AnchorPolygon].
## Only the [member Control.position] (top-left corner) is used to 
## determine the polygon vertex position, [member Control.size] has no effect.
class_name VertexAnchor extends Control

@export var ratio: Vector2:
	set(r):
		# x
		set_anchor_and_offset(SIDE_LEFT, r.x, 0, true)
		set_anchor_and_offset(SIDE_RIGHT, r.x, 0, true)
		# y
		set_anchor_and_offset(SIDE_BOTTOM, r.y, 0, true)
		set_anchor_and_offset(SIDE_TOP, r.y, 0, true)
		queue_redraw()
	get:
		return Vector2(get_anchor(SIDE_LEFT), get_anchor(SIDE_TOP))


func _ready() -> void:
	item_rect_changed.connect(_on_move)


func _on_move() -> void:
	var parent: Node = get_parent()
	if parent is AnchorPolygon:
		parent.queue_redraw()
