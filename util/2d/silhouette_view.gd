class_name SilhouetteView
extends Node2D

@export var source: SilhouetteSource


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _enter_tree() -> void:
	RenderingServer.frame_pre_draw.connect(_follow_anchor)


func _exit_tree() -> void:
	RenderingServer.frame_pre_draw.disconnect(_follow_anchor)


func _draw() -> void:
	if is_instance_valid(source):
		draw_texture(source.get_texture(), -Vector2(source.canvas_size) / 2.0)


func _follow_anchor() -> void:
	if is_instance_valid(source) and is_instance_valid(source.anchor):
		global_transform = source.get_anchor_transform()
