@tool
class_name OrbitPath
extends Node2D

@export var radius: float = 64.0:
	set(value):
		radius = value
		queue_redraw()
@export var dash_count: int = 24
@export_range(0.0, 1.0) var dash_fraction: float = 0.5
@export var color: Color = Color(1.0, 1.0, 1.0, 0.4)
@export var width: float = 1.0
@export var points_per_dash: int = 8


func _draw() -> void:
	var step: float = TAU / dash_count
	for dash: int in dash_count:
		var start: float = step * dash
		draw_arc(Vector2.ZERO, radius, start, start + step * dash_fraction, points_per_dash, color, width)
