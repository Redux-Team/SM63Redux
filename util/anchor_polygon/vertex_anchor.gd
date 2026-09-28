@tool
## A vertex for an [AnchorPolygon].
## Only the [member Control.position] (top-left corner) is used to 
## determine the polygon vertex position, [member Control.size] has no effect.
class_name VertexAnchor extends Control

func _get_configuration_warnings() -> PackedStringArray:
	if get_parent() is AnchorPolygon:
		return []
	else:
		return ["Parent node of a VertexAnchor must be an AnchorPolygon."]

func _ready() -> void:
	item_rect_changed.connect(_on_move)

func _on_move() -> void:
	var parent: Node = get_parent()
	if parent is AnchorPolygon:
		parent.queue_redraw()
