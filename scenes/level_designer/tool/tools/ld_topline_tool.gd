class_name LDToplineTool
extends LDWidgetTool

@export var on_style: LDHandleStyle
@export var off_style: LDHandleStyle
@export var on_color: Color = Color("7ed957")
@export var off_color: Color = Color(1.0, 1.0, 1.0, 0.6)


static func is_available(objects: Array[GameObject]) -> bool:
	var target: GameObject = LDPolygonEditTool.get_target(objects)
	if target == null:
		return false
	
	var surface: PolygonSurface = (target.shape as PolygonShape).surface
	return is_instance_valid(surface) and surface.line_mode == PolygonSurface.LineMode.TOPLINE


func _get_targets(objects: Array[GameObject]) -> Array[GameObject]:
	return [LDPolygonEditTool.get_target(objects)] if is_available(objects) else []


func _layout_handles() -> void:
	var shape: PolygonShape = targets.front().shape as PolygonShape
	var to_world: Transform2D = targets.front().get_global_transform()
	for ring: int in shape.holes.size() + 1:
		var points: PackedVector2Array = shape.get_ring_points(ring)
		var flags: Array[bool] = shape.get_topline_flags(ring)
		for edge: int in points.size():
			var middle: Vector2 = (points.get(edge) + points.get((edge + 1) % points.size())) * 0.5
			place_handle(Vector2i(ring, edge), to_world * middle, on_style if flags.get(edge) else off_style)


func _draw_guides(overlay: LDOverlay) -> void:
	var shape: PolygonShape = targets.front().shape as PolygonShape
	var to_world: Transform2D = targets.front().get_global_transform()
	for ring: int in shape.holes.size() + 1:
		var points: PackedVector2Array = shape.get_ring_points(ring)
		var flags: Array[bool] = shape.get_topline_flags(ring)
		for edge: int in points.size():
			var on: bool = flags.get(edge)
			overlay.draw_world_line(to_world * points.get(edge), to_world * points.get((edge + 1) % points.size()), on_color if on else off_color, 3.0 if on else 1.0)


func _on_handle_pressed(handle: LDHandle) -> void:
	toggle(handle.key.x, handle.key.y)


func _on_handle_reset(handle: LDHandle) -> void:
	toggle(handle.key.x, handle.key.y)


func toggle(ring: int, edge: int) -> void:
	var shape: PolygonShape = targets.front().shape as PolygonShape
	var points: PackedVector2Array = shape.get_ring_points(ring)
	var automatic: bool = TerrainPolygon.get_topline_flags(points, ring == 0, shape.get_topline_threshold(), {}, shape.auto_toplines).get(edge)
	var turned_on: bool = not shape.get_topline_flags(ring).get(edge)
	var toplines: Array[Dictionary] = shape.get_toplines()
	if turned_on == automatic:
		toplines.get(ring).erase(edge)
	else:
		toplines.get(ring).set(edge, turned_on)
	
	editor.history_handler.create("Toggle Topline") \
		.do(shape.set_rings.bind(shape.get_rings(), toplines)) \
		.undo(shape.set_rings.bind(shape.get_rings(), shape.get_toplines())) \
		.commit()
