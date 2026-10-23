class_name LDPolygonTool
extends LDPolygonStrokeTool

@export var preview_root: Node2D
@export var preview_modulate: Color = Color(1.0, 1.0, 1.0, 0.6)
@export var invalid_modulate: Color = Color(1.0, 0.35, 0.35, 0.6)

var _preview: GameObject


static func localize(points: PackedVector2Array, origin: Vector2) -> PackedVector2Array:
	var local: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		local.append(point - origin)
	
	return local


func _setup() -> void:
	draw_fill = false
	editor.tool_handler.armed_changed.connect(_on_armed_changed.unbind(1))


func _can_begin(_world_position: Vector2) -> bool:
	return editor.tool_handler.armed != null


func _finish(points: PackedVector2Array) -> void:
	var origin: Vector2 = \
			editor.viewport_handler.snap(TerrainPolygon.get_bounds(points).get_center())
	var object: GameObject = editor.object_handler.spawn(editor.tool_handler.armed.id, origin)
	(object.shape as PolygonShape).set_rings([localize(points, origin)], [{}])
	for property: ObjectProperty in object.properties:
		if editor.tool_handler.should_randomize(property):
			object.set_value(property.key, property.random_value())
	
	editor.object_handler.add_objects(
			[object],
			editor.level_handler.active_layer,
			"Place %s" % editor.tool_handler.armed.display_name,
			false,
	)


func _stroke_changed() -> void:
	var layer: LevelLayer = editor.level_handler.active_layer
	var points: PackedVector2Array = get_preview_points()
	if (
			points.size() < PolygonShape.MIN_POINTS
			or layer == null
			or editor.tool_handler.armed == null
	):
		_clear_preview()
		return
	
	if _preview == null:
		_preview = editor.object_handler.spawn(editor.tool_handler.armed.id, Vector2.ZERO)
		preview_root.add_child(_preview)
	
	preview_root.global_transform = layer.get_objects_root().get_global_transform()
	(_preview.shape as PolygonShape).set_rings([points], [{}])
	_preview.modulate = preview_modulate if is_simple(points) else invalid_modulate


func _clear_preview() -> void:
	if _preview:
		_preview.free()
		_preview = null


func _on_armed_changed() -> void:
	if is_active():
		reset()
