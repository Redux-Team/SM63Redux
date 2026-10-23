@tool
class_name PolygonToplineStyle
extends Resource

@export var style_name: String
@export var texture: Texture2D
@export var color: Color = Color.WHITE
@export var width: float = 30.0
@export_range(-1.0, 1.0, 0.01) var angle_threshold: float = 0.55
@export var scroll_speed: float = 0.0
@export var ripple_amplitude: float = 0.0
@export var ripple_frequency: float = 1.0
@export var ripple_speed: float = 1.0
@export_group("Caps", "cap")
@export var cap_left: Texture2D
@export var cap_right: Texture2D
@export var cap_inset: float = 4.0
@export_group("Shadow", "shadow")
@export var shadow_texture: Texture2D
@export var shadow_color: Color = Color(1.0, 1.0, 1.0, 0.6)
@export var shadow_width: float = 37.0
@export var shadow_gap: float = 0.0


func make_line_style() -> TerrainPolygon.LineStyle:
	return TerrainPolygon.LineStyle.new(
			width,
			texture,
			color,
			scroll_speed,
			ripple_amplitude,
			ripple_frequency,
			ripple_speed,
	)


func make_shadow_style() -> TerrainPolygon.LineStyle:
	return TerrainPolygon.LineStyle.new(
			shadow_width,
			shadow_texture,
			shadow_color,
			scroll_speed,
			ripple_amplitude,
			ripple_frequency,
			ripple_speed,
	)


func make_cap_style() -> TerrainPolygon.CapStyle:
	return TerrainPolygon.CapStyle.new(cap_left, cap_right, cap_inset)
