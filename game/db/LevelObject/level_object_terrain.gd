@tool
class_name LevelObjectTerrain
extends LevelObject


@export var terrain_data: TerrainData:
	set(v):
		terrain_data = v
		_update_visuals()

@export_group("Internal")
@export var _polygon: Polygon2D
@export var _collision: CollisionPolygon2D
@export var _outline: Line2D
@export var _topline_container: Node2D
@export var _topline_shadow_container: Node2D


func _on_init() -> void:
	var raw_points = data.get("polygon_points")
	var points: PackedVector2Array = _array_to_packed_vec2(raw_points)
	
	if data.has("terrain_data_path"):
		terrain_data = load(data.get("terrain_data_path"))
	
	if _polygon:
		_polygon.polygon = points
	
	if _collision:
		_collision.polygon = points
		
	_update_visuals()


func _update_visuals() -> void:
	if not is_node_ready() or not terrain_data:
		return
	
	if _polygon:
		_polygon.texture = terrain_data.base_texture
		_polygon.color = Color.WHITE if terrain_data.base_texture else Color.TRANSPARENT
	
	if not _polygon or _polygon.polygon.size() < 3:
		_clear_visuals()
		return
	
	var points: PackedVector2Array = TerrainPolygon.ensure_clockwise(_polygon.polygon)
	var closed_points: PackedVector2Array = TerrainPolygon.get_closed_points(points)
	var top_segments: Array[PackedVector2Array] = TerrainPolygon.get_topline_segments(points, terrain_data.topline_angle_threshold)
	
	if _topline_container:
		_clear_children(_topline_container)
		for segment: PackedVector2Array in top_segments:
			var line: Line2D = Line2D.new()
			TerrainPolygon.setup_line2d(line)
			line.width = terrain_data.topline_width
			line.texture = terrain_data.topline_texture
			line.points = TerrainPolygon.subdivide_for_line2d(segment, terrain_data.topline_texture)
			_topline_container.add_child(line)
	
	if _topline_shadow_container:
		_clear_children(_topline_shadow_container)
		for segment: PackedVector2Array in top_segments:
			var line: Line2D = Line2D.new()
			TerrainPolygon.setup_line2d(line)
			line.width = terrain_data.topline_width * 1.33
			line.texture = terrain_data.topline_shadow_texture
			line.default_color = Color(1.0, 1.0, 1.0, 0.6)
			line.points = TerrainPolygon.subdivide_for_line2d(segment, terrain_data.topline_shadow_texture)
			_topline_shadow_container.add_child(line)
	
	if _outline:
		TerrainPolygon.setup_line2d(_outline)
		_outline.width = terrain_data.outline_width
		_outline.texture = terrain_data.outline_texture
		_outline.points = TerrainPolygon.subdivide_for_line2d(closed_points, terrain_data.outline_texture)


func _clear_visuals() -> void:
	if _topline_container:
		_clear_children(_topline_container)
	if _topline_shadow_container:
		_clear_children(_topline_shadow_container)
	if _outline:
		_outline.points = PackedVector2Array()


func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		child.queue_free()
