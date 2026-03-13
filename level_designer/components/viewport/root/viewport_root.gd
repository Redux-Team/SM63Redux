class_name LDViewportRoot
extends Node2D

var _box_rect: Rect2
var _is_drawing: bool = false


func show_box(rect: Rect2) -> void:
	_box_rect = rect
	_is_drawing = true
	queue_redraw()


func hide_box() -> void:
	_is_drawing = false
	queue_redraw()


func _draw() -> void:
	if not _is_drawing:
		return
	
	var style: StyleBox = get_tree().root.get_theme_stylebox(&"SelectionPanel", &"LD")
	if style:
		style.draw(get_canvas_item(), _box_rect)
	else:
		draw_rect(_box_rect, Color(0.4, 0.7, 1.0, 0.15), true)
		draw_rect(_box_rect, Color(0.4, 0.7, 1.0, 0.8), false, 1.0)
