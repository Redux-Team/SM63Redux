@tool
class_name TelescopingShape
extends ObjectShape

signal changed

enum Axis {
	HORIZONTAL,
	VERTICAL,
}

@export var axis: Axis = Axis.HORIZONTAL
@export var patch: NinePatchRect
@export var default_units: int = 1
@export var min_units: int = 0
@export var max_units: int = 32
@export_group("Collision")
@export var collision_shapes: Array[CollisionShape2D]
@export var collision_expand: float = 0.0
@export var stretch_targets: Array[Node2D]
@export var start_anchors: Array[Node2D]

var units: int = -1
var _anchor_offsets: Dictionary[Node2D, Vector2] = {}


func _ready() -> void:
	if units < 0:
		set_units(default_units)
	collision_shapes = collision_shapes.filter(is_instance_valid)
	for node: CollisionShape2D in collision_shapes:
		if node.shape and not node.shape.resource_local_to_scene:
			node.shape = node.shape.duplicate()
	_apply()


func get_kind() -> Kind:
	return Kind.TELESCOPING


func from_data(data: Dictionary) -> void:
	set_units(data.get("units", default_units))


func to_data() -> Dictionary:
	return { "units": units }


func get_local_bounds() -> Rect2:
	if patch == null:
		return Rect2(-8.0, -8.0, 16.0, 16.0)
	
	return Rect2(patch.position, patch.size)


func set_units(value: int) -> void:
	units = clampi(value, min_units, max_units)
	_apply()


func get_axis_vector() -> Vector2:
	return Vector2.RIGHT if axis == Axis.HORIZONTAL else Vector2.DOWN


func get_segment_length() -> float:
	if patch == null or patch.texture == null:
		return 16.0
	
	var texture_size: Vector2 = \
			patch.texture.get_size() if not patch.region_rect.has_area() else patch.region_rect.size
	if axis == Axis.HORIZONTAL:
		return maxf((texture_size.x - patch.patch_margin_left - patch.patch_margin_right), 1.0)
	
	return maxf(texture_size.y - patch.patch_margin_top - patch.patch_margin_bottom, 1.0)


func get_caps_length() -> float:
	if patch == null:
		return 0.0
	
	if axis == Axis.HORIZONTAL:
		return patch.patch_margin_left + patch.patch_margin_right
	
	return patch.patch_margin_top + patch.patch_margin_bottom


func get_length(for_units: int = units) -> float:
	return get_caps_length() + get_segment_length() * maxi(for_units, 0)


func _apply() -> void:
	collision_shapes = collision_shapes.filter(is_instance_valid)
	stretch_targets = stretch_targets.filter(is_instance_valid)
	start_anchors = start_anchors.filter(is_instance_valid)
	if patch == null or units < 0:
		return
	
	var length: float = get_length()
	var size: Vector2 = patch.size
	if axis == Axis.HORIZONTAL:
		size.x = length
	else:
		size.y = length
	patch.size = size
	patch.position = -size * 0.5
	for node: CollisionShape2D in collision_shapes:
		var rectangle: RectangleShape2D = node.shape as RectangleShape2D
		if rectangle:
			var shape_size: Vector2 = rectangle.size
			if axis == Axis.HORIZONTAL:
				shape_size.x = maxf(length + collision_expand, 1.0)
			else:
				shape_size.y = maxf(length + collision_expand, 1.0)
			rectangle.size = shape_size
	for target: Node2D in stretch_targets:
		target.set(&"size", size)
	for anchor: Node2D in start_anchors:
		anchor.position = (
				_anchor_offsets.get_or_add(anchor, anchor.position)
				- get_axis_vector() * length * 0.5
		)
	
	changed.emit()
