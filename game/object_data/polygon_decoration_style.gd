@tool
class_name PolygonDecorationStyle
extends Resource


@export var style_name: String
@export var weightmap: Dictionary[Texture2D, float] = {}
@export_range(0.1, 100.0, 0.1) var density: float = 20.0
