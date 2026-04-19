@warning_ignore_start("unused_private_class_variable")
@tool
class_name LDObject
extends Node2D

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

@export_group("Editor Props")
@export var editor_shape_area: Area2D
@export var editor_placement_rect: Node2D
@export var editor_shape_areas: Array[Area2D]
@export var origin_marker: Marker2D
@export var shader_objects: Array[CanvasItem]

var source_object_id: String = ""
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


func _on_preview() -> void:
	pass


func _on_place() -> void:
	pass


func place() -> void:
	is_preview = false
	for prop: LDProperty in _properties:
		_apply_property(prop.key, _property_values.get(prop.key, prop.default_value))


func init_properties(obj: GameObject) -> void:
	source_object_id = obj.id
	_properties = obj.ld_properties
	for prop: LDProperty in _properties:
		_property_values[prop.key] = prop.default_value
		if prop.key == &"position":
			continue
		if prop.key == &"path_points":
			continue
		_apply_property(prop.key, prop.default_value)


func set_property(key: StringName, value: Variant) -> void:
	for prop: LDProperty in _properties:
		if prop.key == key:
			value = prop.clamp_value(value)
			break
	_property_values[key] = value
	_apply_property(key, value)
	_on_property_changed(key, value)


func get_property(key: StringName) -> Variant:
	return _property_values.get(key)


func get_property_values() -> Dictionary[StringName, Variant]:
	return _property_values.duplicate()


func has_property(key: String) -> bool:
	return _property_values.has(key)


func is_telescoping_x() -> bool:
	return _property_values.has(&"t_size_x")


func is_telescoping_y() -> bool:
	return _property_values.has(&"t_size_y")


func set_selection_state(state: SelectionState) -> void:
	for item: CanvasItem in shader_objects:
		if item and item.material is ShaderMaterial:
			(item.material as ShaderMaterial).set_shader_parameter(&"state", state)


func get_all_editor_shape_areas() -> Array[Area2D]:
	var result: Array[Area2D] = []
	if editor_shape_area:
		result.append(editor_shape_area)
	for area: Area2D in editor_shape_areas:
		if area:
			result.append(area)
	return result


func get_stamp_size() -> Vector2:
	if not editor_placement_rect:
		return Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE)
	return (editor_placement_rect.shape as RectangleShape2D).get_rect().size * global_scale


func _on_property_changed(_key: StringName, _value: Variant) -> void:
	pass


func _apply_property(key: StringName, value: Variant) -> void:
	for prop: LDProperty in _properties:
		if prop.key == key:
			prop.apply(self, value)
			return
