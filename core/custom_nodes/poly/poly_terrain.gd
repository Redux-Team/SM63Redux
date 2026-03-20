@tool 
class_name PolyTerrain
extends Node2D

@export var points: PackedVector2Array
@export var base_texture: Texture2D

@export_group("Topline", "topline")
@export var topline_texture: Texture2D
@export var topline_shadow: Texture2D
@export var topline_left_end: Texture2D
@export var topline_right_end: Texture2D
@export var topline_angle: Vector2 = Vector2(-50, 180 + 50)

@export_group("Outline", "outline")
@export var outline_texture: Texture2D

@export_group("Internal")
@export var _polygon: Polygon2D
@export var _topline: Line2D
@export var _topline_shadow: Line2D
@export var _outline: Line2D
