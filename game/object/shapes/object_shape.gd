@tool
@abstract class_name ObjectShape
extends Node2D

enum Kind {
	NONE,
	POLYGON,
	PATH,
	TELESCOPING,
}


@abstract func get_kind() -> Kind
@abstract func from_data(data: Dictionary) -> void
@abstract func to_data() -> Dictionary
@abstract func get_local_bounds() -> Rect2
