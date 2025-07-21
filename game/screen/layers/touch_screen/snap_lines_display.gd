extends Control

const SNAP_LINE_COLOR: Color = Color.RED
const SNAP_LINE_WIDTH: float = 1.0

var _snap_lines: Array[Vector2] = []


func set_snap_lines(lines: Array[Vector2] = []) -> void:
	_snap_lines = lines
	queue_redraw()


func _draw() -> void:
	for i: int in range(0, _snap_lines.size(), 2):
		if i + 1 < _snap_lines.size():
			var from: Vector2 = _snap_lines[i] - global_position
			var to: Vector2 = _snap_lines[i + 1] - global_position
			draw_line(from, to, SNAP_LINE_COLOR, SNAP_LINE_WIDTH)
