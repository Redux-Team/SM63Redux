@tool
class_name PolygonToplineStyle
extends Resource


@export var style_name: String
@export var topline_texture: Texture2D
@export var topline_shadow_texture: Texture2D
@export var topline_left_end: Texture2D
@export var topline_right_end: Texture2D
@export var topline_width: float = 30.0
@export_range(-1.0, 1.0, 0.01) var topline_angle_threshold: float = 0.55
