@tool
@abstract class_name ObjectShape
extends Node2D

enum Kind {
	NONE,
	POLYGON,
	PATH,
	TELESCOPING,
	BLOCK,
}


@abstract func get_kind() -> Kind
@abstract func from_data(data: Dictionary) -> void
@abstract func to_data() -> Dictionary
@abstract func get_local_bounds() -> Rect2


func contains_point(local_point: Vector2) -> bool:
	return get_local_bounds().has_point(local_point)


func get_outlines() -> Array[PackedVector2Array]:
	var rect: Rect2 = get_local_bounds()
	return [PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])]
