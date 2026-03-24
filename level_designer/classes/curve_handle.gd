class_name LDCurveHandle


var in_offset: Vector2
var out_offset: Vector2


func _init(p_in: Vector2, p_out: Vector2) -> void:
	in_offset = p_in
	out_offset = p_out


static func from_tangent(angle: float, length: float = 80.0) -> LDCurveHandle:
	return LDCurveHandle.new(
		Vector2.from_angle(angle + PI * 0.5) * length,
		Vector2.from_angle(angle + PI * 1.5) * length
	)


func move_in(delta: Vector2) -> void:
	in_offset += delta
	if Input.is_key_pressed(KEY_ALT):
		return
	var angle: float = in_offset.angle()
	var len_in: float = in_offset.length()
	var len_out: float = out_offset.length()
	out_offset = Vector2.from_angle(angle + PI) * (len_in if not Input.is_key_pressed(KEY_SHIFT) else len_out)


func move_out(delta: Vector2) -> void:
	out_offset += delta
	if Input.is_key_pressed(KEY_ALT):
		return
	var angle: float = out_offset.angle()
	var len_out: float = out_offset.length()
	var len_in: float = in_offset.length()
	in_offset = Vector2.from_angle(angle + PI) * (len_out if not Input.is_key_pressed(KEY_SHIFT) else len_in)
