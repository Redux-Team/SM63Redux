class_name LDOverlay
extends LDComponent

@export var canvas: Control
@export var selection_color: Color = Color("6496ed")
@export var hover_color: Color = Color(1.0, 1.0, 1.0, 0.5)


func _setup() -> void:
	canvas.draw.connect(_on_draw)


func _process(_delta: float) -> void:
	canvas.queue_redraw()


func draw_object_outline(object: GameObject, color: Color, width: float = 1.0) -> void:
	var rect: Rect2 = object.get_local_bounds()
	var to_screen: Transform2D = editor.world.get_canvas_transform() * object.get_global_transform()
	var corners: PackedVector2Array = PackedVector2Array([
		to_screen * rect.position,
		to_screen * Vector2(rect.end.x, rect.position.y),
		to_screen * rect.end,
		to_screen * Vector2(rect.position.x, rect.end.y),
		to_screen * rect.position,
	])
	canvas.draw_polyline(corners, color, width)


func draw_world_rect(world_rect: Rect2, color: Color, filled: bool = false) -> void:
	var to_screen: Transform2D = editor.world.get_canvas_transform()
	var rect: Rect2 = Rect2(to_screen * world_rect.position, world_rect.size * to_screen.get_scale())
	canvas.draw_rect(rect, color, filled)


func draw_world_line(from: Vector2, to: Vector2, color: Color, width: float = 1.0) -> void:
	var to_screen: Transform2D = editor.world.get_canvas_transform()
	canvas.draw_line(to_screen * from, to_screen * to, color, width)


func draw_world_circle(center: Vector2, radius: float, color: Color) -> void:
	canvas.draw_circle(editor.world.get_canvas_transform() * center, radius, color, false)


func _on_draw() -> void:
	if editor.level_handler.active_area == null:
		return
	
	var hovered: GameObject = editor.viewport_handler.pick(editor.viewport_handler.get_world_mouse())
	if hovered and not editor.object_handler.selection.has(hovered):
		draw_object_outline(hovered, hover_color)
	
	for object: GameObject in editor.object_handler.selection.get_objects():
		draw_object_outline(object, selection_color)
	
	editor.tool_handler.active_tool._draw_overlay(self)
