class_name SilhouetteView
extends Node2D

@export var source: SilhouetteSource


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	process_physics_priority = 1
	_follow_anchor()
	reset_physics_interpolation()


func _physics_process(_delta: float) -> void:
	_follow_anchor()


func _draw() -> void:
	if is_instance_valid(source):
		draw_texture(source.get_texture(), -Vector2(source.canvas_size) / 2.0)


func _follow_anchor() -> void:
	if is_instance_valid(source) and is_instance_valid(source.anchor):
		global_transform = source.anchor.global_transform
