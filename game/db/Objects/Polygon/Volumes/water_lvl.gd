@tool
class_name LevelObjectWater
extends LevelObjectTerrain


const MAX_SPLASHES: int = 8


@export_group("Water Internal")
@export var _water_area: Area2D
@export var _water_collision: CollisionPolygon2D
@export var _topline_shader: ShaderMaterial


var _splash_positions: Array[float] = []
var _splash_ages: Array[float] = []
var _live_materials: Array[ShaderMaterial] = []


func _on_init() -> void:
	super._on_init()
	if Engine.is_editor_hint():
		return
	_water_area.body_entered.connect(_on_body_entered)
	_water_area.body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_tick_splashes(delta)


func _tick_splashes(delta: float) -> void:
	var i: int = 0
	while i < _splash_ages.size():
		_splash_ages[i] += delta
		if _splash_ages[i] >= float(_topline_shader.get_shader_parameter("splash_max_age")):
			_splash_positions.remove_at(i)
			_splash_ages.remove_at(i)
		else:
			i += 1
	_flush_splash_uniforms()


func _flush_splash_uniforms() -> void:
	var count: int = _splash_positions.size()
	var pos_arr: Array[Vector2] = []
	var age_arr: Array[float] = []
	for j: int in MAX_SPLASHES:
		if j < count:
			pos_arr.append(Vector2(_splash_positions.get(j), 0.0))
			age_arr.append(_splash_ages.get(j))
		else:
			pos_arr.append(Vector2.ZERO)
			age_arr.append(0.0)
	_topline_shader.set_shader_parameter("splash_count", count)
	_topline_shader.set_shader_parameter("splash_positions", pos_arr)
	_topline_shader.set_shader_parameter("splash_ages", age_arr)


func _on_body_entered(body: Node2D) -> void:
	_register_splash(body.global_position)


func _on_body_exited(body: Node2D) -> void:
	_register_splash(body.global_position)


func _register_splash(world_pos: Vector2) -> void:
	if _splash_positions.size() >= MAX_SPLASHES:
		_splash_positions.remove_at(0)
		_splash_ages.remove_at(0)
	_splash_positions.append(_closest_arc_on_outline(to_local(world_pos)))
	_splash_ages.append(0.0)


func _closest_arc_on_outline(local_pos: Vector2) -> float:
	if _outer_points.size() < 2:
		return 0.0
	var closed: PackedVector2Array = TerrainPolygon.get_closed_points(
		TerrainPolygon.ensure_counter_clockwise(_outer_points)
	)
	var arc: float = 0.0
	var best_arc: float = 0.0
	var best_dist: float = INF
	for i: int in range(closed.size() - 1):
		var a: Vector2 = closed.get(i)
		var b: Vector2 = closed.get(i + 1)
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


func _rebuild_polygon() -> void:
	super._rebuild_polygon()
	_sync_water_collision()


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
	if _outer_points.size() < 3:
		_clear_visuals()
		return
	_clear_visuals()
	_build_water_outline()


func _build_water_outline() -> void:
	if not _outline_container or not _topline_shader:
		return
	var closed: PackedVector2Array = TerrainPolygon.get_closed_points(
		TerrainPolygon.ensure_counter_clockwise(_outer_points)
	)
	var outer_mat: ShaderMaterial = _topline_shader.duplicate()
	var outer_inst: MeshInstance2D = _build_ribbon_mesh(closed, polygon_data.outline_width, outer_mat)
	outer_inst.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_outline_container.add_child(outer_inst)
	for hole: PackedVector2Array in _holes:
		var closed_hole: PackedVector2Array = TerrainPolygon.get_closed_points(
			TerrainPolygon.ensure_clockwise(hole)
		)
		var hole_mat: ShaderMaterial = _topline_shader.duplicate()
		var hole_inst: MeshInstance2D = _build_ribbon_mesh(closed_hole, polygon_data.outline_width, hole_mat)
		hole_inst.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_outline_container.add_child(hole_inst)


func _build_ribbon_mesh(points: PackedVector2Array, ribbon_width: float, mat: ShaderMaterial) -> MeshInstance2D:
	var total_length: float = 0.0
	for i: int in range(1, points.size()):
		total_length += points.get(i - 1).distance_to(points.get(i))
	mat.set_shader_parameter("outline_length", total_length)
	var half: float = ribbon_width * 0.5
	var verts: PackedVector2Array = PackedVector2Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	var arc: float = 0.0
	for i: int in range(points.size() - 1):
		var a: Vector2 = points.get(i)
		var b: Vector2 = points.get(i + 1)
		var seg_len: float = a.distance_to(b)
		var tangent: Vector2 = (b - a) / seg_len if seg_len > 0.001 else Vector2.RIGHT
		var perp: Vector2 = Vector2(-tangent.y, tangent.x)
		var packed_n: Color = Color(perp.x * 0.5 + 0.5, perp.y * 0.5 + 0.5, 0.0, 1.0)
		var arc_b: float = arc + seg_len
		var base: int = verts.size()
		verts.append(a + perp * half)
		verts.append(a - perp * half)
		verts.append(b + perp * half)
		verts.append(b - perp * half)
		uvs.append(Vector2(arc, 0.0))
		uvs.append(Vector2(arc, 1.0))
		uvs.append(Vector2(arc_b, 0.0))
		uvs.append(Vector2(arc_b, 1.0))
		colors.append(packed_n)
		colors.append(packed_n)
		colors.append(packed_n)
		colors.append(packed_n)
		indices.append(base)
		indices.append(base + 1)
		indices.append(base + 2)
		indices.append(base + 1)
		indices.append(base + 3)
		indices.append(base + 2)
		arc = arc_b
	var arr_mesh: ArrayMesh = ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var inst: MeshInstance2D = MeshInstance2D.new()
	inst.mesh = arr_mesh
	inst.material = mat
	return inst


func _sync_water_collision() -> void:
	if not _water_collision or _outer_points.size() < 3:
		return
	_water_collision.polygon = _outer_points
