extends Control

const POINT = preload("uid://cllw4u30n478l")

@export var points: Array[LDCurvePoint]

var last_segment_index: int = -1
# this is like the "stickiness" of the point along the curve (for the mouse)
var hysteresis_threshold: float = 8.0


func _ready() -> void:
	get_window().content_scale_factor = 0.6


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		if last_segment_index != -1:
			add_point_at_closest()


func cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var mt: float = 1.0 - t
	return mt * mt * mt * p0 + 3.0 * mt * mt * t * p1 + 3.0 * mt * t * t * p2 + t * t * t * p3


func cubic_bezier_derivative(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var mt: float = 1.0 - t
	return 3.0 * mt * mt * (p1 - p0) + 6.0 * mt * t * (p2 - p1) + 3.0 * t * t * (p3 - p2)


func cubic_bezier_second_derivative(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var mt: float = 1.0 - t
	return 6.0 * mt * (p2 - 2.0 * p1 + p0) + 6.0 * t * (p3 - 2.0 * p2 + p1)


func bezier_initial_t(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, mouse: Vector2) -> float:
	var best_t: float = 0.0
	var best_d: float = INF
	for i: int in range(11):
		var t: float = float(i) / 10.0
		var p: Vector2 = cubic_bezier(p0, p1, p2, p3, t)
		var d: float = p.distance_squared_to(mouse)
		if d < best_d:
			best_d = d
			best_t = t
	return best_t


func bezier_closest_t(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, mouse: Vector2) -> float:
	var t: float = bezier_initial_t(p0, p1, p2, p3, mouse)
	for _i: int in range(4):
		var p: Vector2 = cubic_bezier(p0, p1, p2, p3, t)
		var d1: Vector2 = cubic_bezier_derivative(p0, p1, p2, p3, t)
		var d2: Vector2 = cubic_bezier_second_derivative(p0, p1, p2, p3, t)
		var f: float = (p - mouse).dot(d1)
		var df: float = d1.dot(d1) + (p - mouse).dot(d2)
		if df != 0.0:
			var step: float = f / df
			var max_step: float = 0.25
			if step > max_step:
				step = max_step
			elif step < -max_step:
				step = -max_step
			t -= step
		t = clamp(t, 0.0, 1.0)
	return t


func bezier_closest_point(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, mouse: Vector2) -> Vector2:
	var t: float = bezier_closest_t(p0, p1, p2, p3, mouse)
	return cubic_bezier(p0, p1, p2, p3, t)


func draw_cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, color: Color, width: float, steps: int) -> void:
	var prev: Vector2 = p0
	for i: int in range(1, steps + 1):
		var t: float = float(i) / float(steps)
		var curr: Vector2 = cubic_bezier(p0, p1, p2, p3, t)
		draw_line(prev, curr, color, width)
		prev = curr


func get_handles(point: LDCurvePoint) -> Dictionary:
	var h_in: TestDraggable = point.in_handle
	var h_out: TestDraggable = point.out_handle
	if h_in and not h_in.visible:
		h_in = null
	if h_out and not h_out.visible:
		h_out = null
	return {
		"in": h_in,
		"out": h_out,
		"has": h_in != null and h_out != null
	}


func perpendicular_tangent(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var derivative: Vector2 = cubic_bezier_derivative(p0, p1, p2, p3, t)
	return Vector2(-derivative.y, derivative.x).normalized()


func calculate_tangent_angle(point_index: int) -> float:
	var count: int = points.size()
	var prev: LDCurvePoint = points[(point_index - 1 + count) % count]
	var curr: LDCurvePoint = points[point_index]
	var next: LDCurvePoint = points[(point_index + 1) % count]
	
	var prev_h: Dictionary = get_handles(prev)
	var next_h: Dictionary = get_handles(next)
	
	var tangent_in: Vector2 = Vector2.ZERO
	var tangent_out: Vector2 = Vector2.ZERO
	
	if prev_h["has"]:
		var p0: Vector2 = prev.position
		var p1: Vector2 = prev.position + prev_h["out"].position
		var p2: Vector2 = curr.position
		var p3: Vector2 = curr.position
		tangent_in = cubic_bezier_derivative(p0, p1, p2, p3, 0.99).normalized()
	else:
		tangent_in = (curr.position - prev.position).normalized()
	
	if next_h["has"]:
		var p0: Vector2 = curr.position
		var p1: Vector2 = curr.position
		var p2: Vector2 = next.position + next_h["in"].position
		var p3: Vector2 = next.position
		tangent_out = cubic_bezier_derivative(p0, p1, p2, p3, 0.01).normalized()
	else:
		tangent_out = (next.position - curr.position).normalized()
	
	var avg_tangent: Vector2 = (tangent_in + tangent_out).normalized()
	return avg_tangent.angle() + (PI / 2.0)


func add_point_at_closest() -> void:
	var mouse: Vector2 = get_local_mouse_position()
	var i: int = last_segment_index
	var count: int = points.size()
	var p: LDCurvePoint = points[i]
	var n: LDCurvePoint = points[(i + 1) % count]
	var ph: Dictionary = get_handles(p)
	var nh: Dictionary = get_handles(n)
	
	var new_point: LDCurvePoint = POINT.duplicate().instantiate()
	
	if ph["has"] or nh["has"]:
		var p0: Vector2 = p.position
		var p1: Vector2 = (p.position + ph["out"].position) if ph["has"] else p.position
		var p2: Vector2 = (n.position + nh["in"].position) if nh["has"] else n.position
		var p3: Vector2 = n.position
		
		var t: float = bezier_closest_t(p0, p1, p2, p3, mouse)
		
		var q0: Vector2 = p0.lerp(p1, t)
		var q1: Vector2 = p1.lerp(p2, t)
		var q2: Vector2 = p2.lerp(p3, t)
		var r0: Vector2 = q0.lerp(q1, t)
		var r1: Vector2 = q1.lerp(q2, t)
		var split_point: Vector2 = r0.lerp(r1, t)
		
		new_point.position = split_point
	else:
		var cp: Vector2 = Geometry2D.get_closest_point_to_segment(mouse, p.position, n.position)
		new_point.position = cp
	
	points.insert(i + 1, new_point)
	add_child(new_point)


func _draw() -> void:
	var count: int = points.size()
	var mouse: Vector2 = get_local_mouse_position()
	var closest_point: Vector2 = Vector2.ZERO
	var best_dist: float = INF
	var found_any: bool = false
	
	for i: int in range(count):
		var p: LDCurvePoint = points[i]
		var n: LDCurvePoint = points[(i + 1) % count]
		var ph: Dictionary = get_handles(p)
		var nh: Dictionary = get_handles(n)
		
		if ph["has"] or nh["has"]:
			var p0: Vector2 = p.position
			var p1: Vector2 = (p.position + ph["out"].position) if ph["has"] else p.position
			var p2: Vector2 = (n.position + nh["in"].position) if nh["has"] else n.position
			var p3: Vector2 = n.position
			
			draw_cubic_bezier(p0, p1, p2, p3, Color.WHITE, 2.0, 32)
			
			if ph["has"]:
				draw_line(p.position, p.position + ph["in"].position, Color.YELLOW, 1.0)
				draw_line(p.position, p.position + ph["out"].position, Color.YELLOW, 1.0)
			if nh["has"]:
				draw_line(n.position, n.position + nh["in"].position, Color.YELLOW, 1.0)
				draw_line(n.position, n.position + nh["out"].position, Color.YELLOW, 1.0)
			
			var cp: Vector2 = bezier_closest_point(p0, p1, p2, p3, mouse)
			var d: float = cp.distance_squared_to(mouse)
			
			var seg_index: int = i
			if last_segment_index == -1 or seg_index == last_segment_index:
				if d < best_dist:
					best_dist = d
					closest_point = cp
					found_any = true
					last_segment_index = seg_index
			else:
				if d < best_dist - hysteresis_threshold: 
					best_dist = d
					closest_point = cp
					found_any = true
					last_segment_index = seg_index
		else:
			draw_line(p.position, n.position, Color.WHITE, 2.0)
			
			var cp2: Vector2 = Geometry2D.get_closest_point_to_segment(mouse, p.position, n.position)
			var d2: float = cp2.distance_squared_to(mouse)
			
			var seg_index2: int = i
			if last_segment_index == -1 or seg_index2 == last_segment_index:
				if d2 < best_dist:
					best_dist = d2
					closest_point = cp2
					found_any = true
					last_segment_index = seg_index2
			else:
				if d2 < best_dist - hysteresis_threshold:
					best_dist = d2
					closest_point = cp2
					found_any = true
					last_segment_index = seg_index2
	
	if found_any:
		draw_circle(closest_point, 5.0, Color.RED)


func _process(_delta: float) -> void:
	queue_redraw()
