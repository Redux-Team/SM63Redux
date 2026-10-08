@tool
## Draws a solid coloured polygon, with vertices positioned at child [VertexAnchor] positions,
## thus allowing them to change based on screen sizes, and be animated using an [AnimationPlayer].
class_name AnchorPolygon extends Control

@export var color: Color:
	set(new_color):
		color = new_color
		queue_redraw()
@export var ignored_anchors: Array[VertexAnchor]


# Should redraw on: 
#	this node resized (done automatically by Godot)
#	any child moved (done in VertexAnchor script)
#	child node order changed (done automatically by Godot)
#	recoloured (done with setter)
func _draw() -> void:
	var position_array: PackedVector2Array = PackedVector2Array()
	for node: Node in get_children():
		if node is VertexAnchor and node not in ignored_anchors:
			position_array.append(node.position)
	draw_colored_polygon(position_array, color)
