@tool
class_name BlockShape
extends ObjectShape

signal changed

@export var default_size: Vector2 = Vector2(32, 32)
@export var min_size: Vector2 = Vector2(32, 32)
@export var max_size: Vector2 = Vector2(1024, 1024)
@export var padding: float = 2.0
@export var rects: Array[Control]
@export var collision_shapes: Array[CollisionShape2D]

var size: Vector2 = Vector2.ZERO


func _ready() -> void:
	if size == Vector2.ZERO:
		set_size(default_size)
	collision_shapes = collision_shapes.filter(is_instance_valid)
	for node: CollisionShape2D in collision_shapes:
		if node.shape:
			node.shape = node.shape.duplicate()
	_apply()


func get_kind() -> Kind:
	return Kind.BLOCK


func from_data(data: Dictionary) -> void:
	set_size(data.get("size", default_size))


func to_data() -> Dictionary:
	return {"size": size}


func set_size(value: Vector2) -> void:
	size = value.clamp(min_size, max_size)
	_apply()


func get_local_bounds() -> Rect2:
	var visual: Vector2 = size + Vector2.ONE * padding
	return Rect2(-visual * 0.5, visual)


func _apply() -> void:
	rects = rects.filter(is_instance_valid)
	collision_shapes = collision_shapes.filter(is_instance_valid)
	var visual: Vector2 = size + Vector2.ONE * padding
	for rect: Control in rects:
		rect.size = visual
		rect.position = -visual * 0.5
		rect.pivot_offset = visual * 0.5
	for node: CollisionShape2D in collision_shapes:
		var rectangle: RectangleShape2D = node.shape as RectangleShape2D
		if rectangle:
			rectangle.size = visual
	
	changed.emit()
