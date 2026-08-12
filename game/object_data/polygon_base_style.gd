@tool
class_name PolygonBaseStyle
extends Resource


@export var style_name: String
@export var texture: Texture2D
@export var color: Color = Color.WHITE

@export_group("Outline", "outline")
@export var outline_texture: Texture2D
@export var outline_color: Color = Color.WHITE
@export var outline_width: float = 7.0
@export var outline_scroll_speed: float = 0.0
@export var outline_ripple_amplitude: float = 0.0
@export var outline_ripple_frequency: float = 1.0
@export var outline_ripple_speed: float = 1.0


func make_outline_style() -> TerrainPolygon.LineStyle:
	return TerrainPolygon.LineStyle.new(
		outline_width,
		outline_texture,
		outline_color,
		outline_scroll_speed,
		outline_ripple_amplitude,
		outline_ripple_frequency,
		outline_ripple_speed
	)
