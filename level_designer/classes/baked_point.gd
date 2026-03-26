class_name LDBakedPoint


var position: Vector2
var segment_index: int
var t: float
var is_anchor: bool


func _init(p: Vector2, si: int, param_t: float, anchor: bool) -> void:
	position = p
	segment_index = si
	t = param_t
	is_anchor = anchor
