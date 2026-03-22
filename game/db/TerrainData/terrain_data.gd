class_name TerrainData
extends Resource

signal update_visuals
signal redraw

@export var base_texture: Texture2D:
	set(t):
		base_texture = t
		update_visuals.emit()

@export_group("Topline", "topline")
@export var topline_texture: Texture2D:
	set(t):
		topline_texture = t
		update_visuals.emit()

@export var topline_shadow_texture: Texture2D:
	set(t):
		topline_shadow_texture = t
		update_visuals.emit()

@export var topline_left_end: Texture2D:
	set(t):
		topline_left_end = t
		update_visuals.emit()

@export var topline_right_end: Texture2D:
	set(t):
		topline_right_end = t
		update_visuals.emit()

## Minimum dot product with Vector2.UP for an edge to be considered a topline edge.
## 0.0 = any upward-facing edge, 1.0 = only perfectly flat edges.
@export_range(-1.0, 1.0, 0.01) var topline_angle_threshold: float = 0.55:
	set(v):
		topline_angle_threshold = v
		update_visuals.emit()

@export_range(0.1, 128.0, 0.1) var topline_width: float = 30.0:
	set(v):
		topline_width = v
		update_visuals.emit()

@export_group("Outline", "outline")
@export var outline_texture: Texture2D:
	set(t):
		outline_texture = t
		update_visuals.emit()

@export var outline_width: float = 7.0:
	set(v):
		outline_width = v
		update_visuals.emit()

@export_group("Display")
@export var border_width: float = 3.0:
	set(v):
		border_width = v
		redraw.emit()
