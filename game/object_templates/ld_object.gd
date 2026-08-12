@warning_ignore_start("unused_private_class_variable")
@tool
class_name LDObject
extends Node2D

const OBJECT_SHADER: Shader = preload("uid://dxlbj210tsi10")
const PREVIEW_MODULATE: Color = Color(1.0, 1.0, 1.0, 0.6)
const DISABLED_MODULATE: Color = Color(0.5, 0.5, 0.5, 0.8)

enum SelectionState {
	HIDDEN,
	HOVERED,
	SELECTED,
}

@export var is_preview: bool = true:
	set(v):
		is_preview = v
		if is_preview:
			_on_preview()
		else:
			_on_place()
## Greys the object out and stops it answering hit-tests, without removing it from the level.
@export var disabled: bool = false:
	set(v):
		disabled = v
		for area: Area2D in get_all_editor_shape_areas():
			area.monitoring = not v
			area.monitorable = not v
		reset_shader_modulate()

@export_group("Editor Props")
@export var editor_shape_area: Area2D
@export var editor_placement_rect: Node2D
@export var editor_shape_areas: Array[Area2D]
@export var origin_marker: Marker2D
@export var shader_objects: Array[CanvasItem]

var source_object_id: String = ""
var _selection_state: SelectionState = SelectionState.HIDDEN
## Mirrored off the GameObject at init so the selection tools don't have to hit the database for
## every object on every frame of a drag.
var ld_flags: int = 15
var _local_bounds: Rect2 = Rect2()
var _local_bounds_valid: bool = false
var _properties: Array[LDProperty] = []
var _property_values: Dictionary[StringName, Variant] = {}

@export_tool_button("Create Editor Props") var _create_editor_props: Callable:
	get: return func() -> void:
		if not editor_shape_area:
			editor_shape_area = Area2D.new()
			editor_shape_area.name = "EditorShapeArea"
			add_child(editor_shape_area)
			editor_shape_area.owner = self
			
			var editor_shape: CollisionShape2D = CollisionShape2D.new()
			editor_shape.name = "EditorShape"
			editor_shape_area.add_child(editor_shape)
			editor_shape.owner = self
			editor_shape.shape = RectangleShape2D.new()
			
			if not editor_placement_rect:
				editor_placement_rect = editor_shape
		
		if not origin_marker:
			origin_marker = Marker2D.new()
			origin_marker.name = "Origin"
			add_child(origin_marker)
			origin_marker.owner = self


static func get_object_shader(local: bool = true) -> ShaderMaterial:
	var shader_material: ShaderMaterial = ShaderMaterial.new()
	
	var shader: Shader = OBJECT_SHADER
	shader.resource_local_to_scene = local
	shader_material.shader = shader
	
	return shader_material

func _on_preview() -> void:
	pass


func _on_place() -> void:
	pass


func _first_placement() -> void:
	place(true)


func place(first: bool = false) -> void:
	is_preview = false
	for prop: LDProperty in _properties:
		_apply_property(prop.key, _property_values.get(prop.key, prop.default_value))

		if first:
			prop._on_first_placement(self, _property_values.get(prop.key, prop.default_value))

	_enforce_uniqueness()


## If this object's GameObject is flagged unique, removes any other placed instance of the same
## object in this object's own area, so each area keeps exactly one (e.g. its own player spawn).
func _enforce_uniqueness() -> void:
	if source_object_id.is_empty() or not LD.is_ready():
		return
	var game_object: GameObject = GameDB.get_db().find_game_object(source_object_id)
	if not game_object or not game_object.ld_unique:
		return
	var area: LDArea = _owning_area()
	if not area:
		return
	for other: LDObject in area.get_all_objects():
		if other == self or other.is_preview:
			continue
		if other.source_object_id == source_object_id:
			if other.get_parent():
				other.get_parent().remove_child(other)
			other.queue_free()


## Walks up the scene tree to the LDArea this object lives in (objects sit under layer → area).
func _owning_area() -> LDArea:
	var node: Node = get_parent()
	while node and node is not LDArea:
		node = node.get_parent()
	return node as LDArea


## The index of the LDLayer this object currently lives on (objects sit under layer → objects_root).
func get_layer_index() -> int:
	var node: Node = get_parent()
	while node and node is not LDLayer:
		node = node.get_parent()
	var layer: LDLayer = node as LDLayer
	return layer.index if layer else 0


func bind_to_active_layer() -> void:
	LDLevel.get_active_area().active_layer_changed.connect(func(index: int) -> void:
		LD.get_area().move_object_to_layer(self, index)
	, CONNECT_REFERENCE_COUNTED)


func init_properties(obj: GameObject) -> void:
	source_object_id = obj.id
	ld_flags = obj.ld_flags
	_properties = obj.ld_properties
	for prop: LDProperty in _properties:
		_property_values[prop.key] = prop.default_value
		if prop.key == &"position":
			continue
		if prop.key == &"path_points":
			continue
		_apply_property(prop.key, prop.default_value)


func set_property(key: StringName, value: Variant) -> void:
	invalidate_local_bounds()
	for prop: LDProperty in _properties:
		if prop.key == key:
			value = prop.clamp_value(value)
			break
	_property_values[key] = value
	_apply_property(key, value)
	_on_property_changed(key, value)


func set_property_no_apply(key: StringName, value: Variant) -> void:
	for prop: LDProperty in _properties:
		if prop.key == key:
			value = prop.clamp_value(value)
			break
	_property_values[key] = value
	_on_property_changed(key, value)


func get_property(key: StringName) -> Variant:
	return _property_values.get(key)


func get_ld_property(key: StringName) -> LDProperty:
	for prop: LDProperty in _properties:
		if prop.key == key:
			return prop
	return null


func get_properties() -> Array[LDProperty]:
	return _properties


func get_property_values() -> Dictionary[StringName, Variant]:
	return _property_values.duplicate()


func get_property_options(_key: StringName) -> PackedStringArray:
	return PackedStringArray()


func has_property(key: String) -> bool:
	return _property_values.has(key)


func is_telescoping_x() -> bool:
	return _property_values.has(&"t_size_x")


func is_telescoping_y() -> bool:
	return _property_values.has(&"t_size_y")


## Re-applying the same state costs a shader parameter write (and for some objects a redraw) per
## call, and the selection tools poll this every frame, so unchanged states are dropped here.
func set_selection_state(state: SelectionState) -> void:
	if _selection_state == state:
		return
	_selection_state = state
	set_shader_parameter(&"state", state)


func set_shader_parameter(parameter: StringName, value: Variant) -> void:
	for item: CanvasItem in shader_objects:
		if item and item.material is ShaderMaterial:
			(item.material as ShaderMaterial).set_shader_parameter(parameter, value)


func set_shader_modulate(color: Color) -> void:
	set_shader_parameter(&"post_modulate", color)


## Re-applies whichever tint the object's current state calls for, so preview and disabled can be
## toggled in either order without one clearing the other.
func reset_shader_modulate() -> void:
	if disabled:
		set_shader_modulate(DISABLED_MODULATE)
	elif is_preview:
		set_shader_modulate(PREVIEW_MODULATE)
	else:
		set_shader_modulate(Color.WHITE)


func get_origin_offset() -> Vector2:
	return origin_marker.position


func get_all_editor_shape_areas() -> Array[Area2D]:
	var result: Array[Area2D] = []
	if editor_shape_area:
		result.append(editor_shape_area)
	for area: Area2D in editor_shape_areas:
		if area:
			result.append(area)
	return result


## Axis-aligned bounds of this object in its own space, unioned over every editor shape it owns
## (a path's stem lives in a second area from its head). Used as a broad-phase reject before the
## exact hit tests, so it only has to be conservative. An empty rect means "no cheap bounds
## available" and callers should skip the reject rather than treat the object as a miss.
func get_local_bounds() -> Rect2:
	if not _local_bounds_valid:
		_local_bounds = _compute_local_bounds()
		_local_bounds_valid = true
	return _local_bounds


## Call when the editor shapes change size or count; the bounds are otherwise cached, because the
## selection tools ask for them once per object per frame.
func invalidate_local_bounds() -> void:
	_local_bounds_valid = false


func _compute_local_bounds() -> Rect2:
	var bounds: Rect2 = Rect2()
	var found: bool = false

	for area: Area2D in get_all_editor_shape_areas():
		for child: Node in area.get_children():
			var shape: CollisionShape2D = child as CollisionShape2D
			if not shape or shape.shape is not RectangleShape2D:
				continue
			var to_local: Transform2D = area.transform * shape.transform
			var rect: Rect2 = (shape.shape as RectangleShape2D).get_rect()
			for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
				var point: Vector2 = to_local * corner
				if found:
					bounds = bounds.expand(point)
				else:
					bounds = Rect2(point, Vector2.ZERO)
					found = true

	return bounds.grow(2.0) if found else Rect2()


func get_stamp_size() -> Vector2:
	if not editor_placement_rect:
		return Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE)
	return (editor_placement_rect.shape as RectangleShape2D).get_rect().size * global_scale

@warning_ignore("unused_parameter")
func _on_property_changed(key: StringName, value: Variant) -> void:
	pass


func _apply_property(key: StringName, value: Variant) -> void:
	for prop: LDProperty in _properties:
		if prop.key == key:
			prop.apply(self, value)
			return
