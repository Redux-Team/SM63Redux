@tool
class_name LevelObjectWater
extends LevelObjectTerrain


const MAX_SPLASHES: int = 8


@export_group("Water")
@export var wave_speed: float = 0.8
@export var wave_amplitude: float = 6.0
@export var wave_frequency: float = 2.0
@export var splash_max_age: float = 1.2
@export var splash_amplitude: float = 18.0
@export var splash_radius: float = 120.0

@export_group("Water Internal")
@export var _water_collision: CollisionPolygon2D


var _splash_positions: Array[float] = []
var _splash_ages: Array[float] = []
var _base_points: PackedVector2Array = PackedVector2Array()


func _on_init() -> void:
	super._on_init()
	_sync_water_collision()


func _register_splash(world_pos: Vector2) -> void:
	if _splash_positions.size() >= MAX_SPLASHES:
		_splash_positions.remove_at(0)
		_splash_ages.remove_at(0)
	_splash_positions.append(_closest_arc_on_outline(to_local(world_pos)))
	_splash_ages.append(0.0)


func _closest_arc_on_outline(local_pos: Vector2) -> float:
	if _base_points.size() < 2:
		return 0.0
	var arc: float = 0.0
	var best_arc: float = 0.0
	var best_dist: float = INF
	for i: int in range(_base_points.size() - 1):
		var a: Vector2 = _base_points.get(i)
		var b: Vector2 = _base_points.get(i + 1)
		var seg: Vector2 = b - a
		var seg_len: float = seg.length()
		if seg_len < 0.001:
			arc += seg_len
			continue
		var t: float = clamp((local_pos - a).dot(seg) / (seg_len * seg_len), 0.0, 1.0)
		var dist: float = local_pos.distance_to(a + seg * t)
		if dist < best_dist:
			best_dist = dist
			best_arc = arc + t * seg_len
		arc += seg_len
	return best_arc



func _update_visuals() -> void:
	if not is_node_ready() or not polygon_data:
		return
	if _polygon:
		if polygon_data.textured and polygon_data.base_texture:
			_polygon.texture = polygon_data.base_texture
			_polygon.color = Color.WHITE
		else:
			_polygon.texture = null
			_polygon.color = polygon_data.base_color
	_clear_visuals()
	if _outer_points.size() < 3:
		return
	_build_water_outline()


func _build_water_outline() -> void:
	if not _outline_container or not polygon_data:
		return
	var textured: bool = polygon_data.textured
	var outline_style: TerrainPolygon.LineStyle = TerrainPolygon.LineStyle.new(
		polygon_data.outline_width,
		polygon_data.outline_texture if textured else null,
		polygon_data.outline_color,
		textured,
		polygon_data.outline_scroll_speed,
		polygon_data.outline_ripple_amplitude,
		polygon_data.outline_ripple_frequency,
		polygon_data.outline_ripple_speed
	)
	TerrainPolygon.add_outline(_outline_container,
		TerrainPolygon.reverse_points(
			TerrainPolygon.get_closed_points(TerrainPolygon.ensure_counter_clockwise(_outer_points))
		),
		outline_style
	)
	for hole: PackedVector2Array in _holes:
		TerrainPolygon.add_outline(_outline_container,
			TerrainPolygon.reverse_points(
				TerrainPolygon.get_closed_points(TerrainPolygon.ensure_clockwise(hole))
			),
			outline_style
		)


func _sync_water_collision() -> void:
	if not _water_collision or not _polygon or _polygon.polygon.is_empty():
		return
	_water_collision.polygon = _polygon.polygon
