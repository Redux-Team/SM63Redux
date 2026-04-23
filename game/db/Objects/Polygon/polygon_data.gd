@tool
class_name PolygonData
extends Resource

signal update_visuals
signal redraw

enum LineMode { TOPLINE, EDGES_ONLY, NONE }

@export var textured: bool = true:
	set(v):
		textured = v
		notify_property_list_changed()
		update_visuals.emit()

@export var base_color: Color = Color.WHITE:
	set(v):
		base_color = v
		update_visuals.emit()

@export var line_mode: LineMode = LineMode.TOPLINE:
	set(v):
		line_mode = v
		notify_property_list_changed()
		update_visuals.emit()

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

@export var outline_color: Color = Color.WHITE:
	set(v):
		outline_color = v
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


func _validate_property(property: Dictionary) -> void:
	var texture_props: Array[StringName] = [
		&"base_texture",
		&"topline_texture", &"topline_shadow_texture",
		&"topline_left_end", &"topline_right_end",
		&"outline_texture",
	]
	var topline_props: Array[StringName] = [
		&"topline_texture", &"topline_shadow_texture",
		&"topline_left_end", &"topline_right_end",
		&"topline_angle_threshold", &"topline_width",
	]
	var outline_props: Array[StringName] = [
		&"outline_texture", &"outline_color", &"outline_width",
	]
	
	var prop: StringName = property.name
	
	if not textured and prop in texture_props:
		property.usage = PROPERTY_USAGE_NO_EDITOR
		return
	
	if line_mode == LineMode.NONE and (prop in topline_props or prop in outline_props):
		property.usage = PROPERTY_USAGE_NO_EDITOR
		return
	
	if line_mode == LineMode.EDGES_ONLY and prop in topline_props:
		property.usage = PROPERTY_USAGE_NO_EDITOR
		return
	
	if not textured and prop == &"outline_color":
		property.usage = PROPERTY_USAGE_DEFAULT
		return
	
	if not textured and prop == &"base_color":
		property.usage = PROPERTY_USAGE_DEFAULT
