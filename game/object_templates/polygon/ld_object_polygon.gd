@tool
class_name LDObjectPolygon
extends LDObject


const PULSE_MIN_ALPHA: float = 0.3
const PULSE_PERIOD: float = 1.25
const STYLE_PROPERTIES: Array[StringName] = [
	&"base_style", &"topline_style", &"decoration_set",
	&"decorations_enabled", &"collision_mode", &"rng_seed",
]


@export var polygon_data: PolygonData:
	set(d):
		polygon_data = d
		if surface:
			surface.data = d

@export_group("Internal")
@export var surface: PolygonSurface

@export_group("Editor Props")
@export var editor_polygon: CollisionPolygon2D
@export var overlay: LDPolygonOverlay


var _preview_valid: bool = true
var _bounds: Rect2 = Rect2()
var _pulse: Tween


static func from_data(data: GameObjectData) -> LDObject:
	var polygon_style: PolygonData = data as PolygonData
	if not polygon_style:
		return null
	
	var instance: LDObjectPolygon = load("res://game/object_templates/polygon/ld_object_polygon.tscn").instantiate()
	instance.polygon_data = polygon_style
	
	return instance


func _ready() -> void:
	if surface:
		surface.data = polygon_data
		if not surface.rebuilt.is_connected(_on_surface_rebuilt):
			surface.rebuilt.connect(_on_surface_rebuilt)
	_sync_style()
	
	if get_property(&"rng_seed") == 0:
		set_property(&"rng_seed", randi())


func _on_preview() -> void:
	modulate = Color(1.0, 1.0, 1.0, 0.6)


func _on_place() -> void:
	modulate = Color.WHITE


func set_selection_state(state: LDObject.SelectionState) -> void:
	if _selection_state == state:
		return
	_selection_state = state
	_sync_pulse()
	var tint: Color = Color.WHITE
	match state:
		LDObject.SelectionState.HOVERED:
			tint = Color(1.0, 1.0, 1.0, 0.7)
		LDObject.SelectionState.SELECTED:
			tint = Color(1.2, 1.2, 1.2, 1.0)
	if surface:
		surface.set_tint(tint)
	_redraw_overlay()


func set_preview_valid(valid: bool) -> void:
	_preview_valid = valid
	_redraw_overlay()


func get_selection_state() -> LDObject.SelectionState:
	return _selection_state


func is_preview_valid() -> bool:
	return _preview_valid


func get_stamp_size() -> Vector2:
	var points: PackedVector2Array = get_outer_points()
	if points.is_empty():
		return Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE)
	var bounds: Rect2 = Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		bounds = bounds.expand(point)
	return bounds.size


func apply_points(points: PackedVector2Array) -> void:
	surface.set_outer(points)


func apply_points_and_holes(points: PackedVector2Array, holes: Array[PackedVector2Array]) -> void:
	surface.set_shape(points, holes)


func add_hole(hole: PackedVector2Array) -> void:
	surface.add_hole(hole)


func remove_hole(index: int) -> void:
	surface.remove_hole(index)


func clear_holes() -> void:
	surface.clear_holes()


func set_hole(index: int, points: PackedVector2Array) -> void:
	surface.set_hole(index, points)


func get_outer_points() -> PackedVector2Array:
	return surface.get_outer()


func get_holes() -> Array[PackedVector2Array]:
	return surface.get_holes()


func get_hole_count() -> int:
	return surface.get_hole_count()


func get_hole(index: int) -> PackedVector2Array:
	return surface.get_hole(index)


func get_ring() -> PackedVector2Array:
	return surface.get_ring()


func get_topline_threshold() -> float:
	return surface.get_topline_threshold()


func get_topline_edges() -> Array[Dictionary]:
	return surface.get_topline_edges()


func get_topline_overrides() -> Dictionary:
	return surface.get_topline_overrides()


func set_topline_overrides(overrides: Dictionary) -> void:
	surface.set_topline_overrides(overrides)


func set_topline_override(key: String, on: bool) -> void:
	surface.set_topline_override(key, on)


func clear_topline_override(key: String) -> void:
	surface.clear_topline_override(key)


func get_property_options(key: StringName) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray(["Default"])
	match key:
		&"base_style":
			for style: PolygonBaseStyle in PolygonStyleDB.get_base_styles():
				result.append(style.style_name)
		&"topline_style":
			for style: PolygonToplineStyle in PolygonStyleDB.get_topline_styles():
				result.append(style.style_name)
		&"decoration_set":
			for style: PolygonDecorationStyle in PolygonStyleDB.get_decoration_styles():
				result.append(style.style_name)
		&"collision_mode":
			result.append_array(PolygonData.COLLISION_MODE_NAMES)
		_:
			return PackedStringArray()
	return result


func _on_property_changed(key: StringName, _value: Variant) -> void:
	if key in STYLE_PROPERTIES:
		_sync_style()


func _sync_style() -> void:
	if not surface:
		return
	surface.base_style_name = _string_property(&"base_style")
	surface.topline_style_name = _string_property(&"topline_style")
	surface.decoration_style_name = _string_property(&"decoration_set")
	surface.collision_mode_name = _string_property(&"collision_mode")
	surface.decorations_enabled = _bool_property(&"decorations_enabled", true)
	surface.rng_seed = _int_property(&"rng_seed")
	surface.rebuild()


func _string_property(key: StringName) -> String:
	var value: Variant = get_property(key)
	return str(value) if value != null else ""


## The saved setting, as opposed to [member PolygonSurface.decorations_enabled], which tools may
## suppress temporarily while dragging.
func get_decorations_enabled() -> bool:
	return _bool_property(&"decorations_enabled", true)


func _bool_property(key: StringName, fallback: bool) -> bool:
	var value: Variant = get_property(key)
	return bool(value) if value != null else fallback


func _int_property(key: StringName) -> int:
	var value: Variant = get_property(key)
	return int(value) if value != null else 0


## The editor shape is only ever read as a point array for select/move hit-tests, so EditorShape
## ships disabled: registering its convex pieces with the physics server costs far more per rebuild
## than the hit-tests ever save.
func _on_surface_rebuilt() -> void:
	if editor_polygon and _preview_valid:
		editor_polygon.polygon = surface.get_ring()
	_bounds = Rect2()
	var points: PackedVector2Array = get_outer_points()
	if not points.is_empty():
		_bounds = Rect2(points[0], Vector2.ZERO)
		for point: Vector2 in points:
			_bounds = _bounds.expand(point)
	_redraw_overlay()


func get_local_bounds() -> Rect2:
	return _bounds


func _redraw_overlay() -> void:
	if overlay:
		overlay.queue_redraw()


func _sync_pulse() -> void:
	if _pulse and _pulse.is_valid():
		_pulse.kill()
	_pulse = null
	
	if not overlay:
		return
	if _selection_state != LDObject.SelectionState.SELECTED or not is_inside_tree():
		overlay.modulate = Color.WHITE
		return
	
	_pulse = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(overlay, "modulate:a", PULSE_MIN_ALPHA, PULSE_PERIOD * 0.5)
	_pulse.tween_property(overlay, "modulate:a", 1.0, PULSE_PERIOD * 0.5)


## Tweens do not survive leaving the tree, so a held editor gets its pulse back on the way in.
func _enter_tree() -> void:
	super()
	if _selection_state == LDObject.SelectionState.SELECTED:
		_sync_pulse.call_deferred()
