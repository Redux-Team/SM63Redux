class_name LDSegment


var point: Vector2
var handle_out: Vector2
var handle_in: Vector2
var is_curve: bool


func _init(p: Vector2, curved: bool = false, h_out: Vector2 = Vector2.ZERO, h_in: Vector2 = Vector2.ZERO) -> void:
	point = p
	is_curve = curved
	handle_out = h_out
	handle_in = h_in


func duplicate() -> LDSegment:
	return LDSegment.new(point, is_curve, handle_out, handle_in)
