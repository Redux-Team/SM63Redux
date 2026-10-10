@tool
class_name UICanvasGroup
extends Control

@export_range(0.0, 1024.0, 1.0, "suffix:px") var fit_margin: float = 10.0:
	set(value):
		fit_margin = value
		_update_group()
@export_range(0.0, 1024.0, 1.0, "suffix:px") var clear_margin: float = 10.0:
	set(value):
		clear_margin = value
		_update_group()
@export var use_mipmaps: bool = false:
	set(value):
		use_mipmaps = value
		_update_group()


func _init() -> void:
	if not material:
		var mat: ShaderMaterial = ShaderMaterial.new()
		material = mat
		mat.shader = preload("uid://cutgicj2s5not")
	_update_group()


func _update_group() -> void:
	RenderingServer.canvas_item_set_canvas_group_mode(get_canvas_item(), RenderingServer.CANVAS_GROUP_MODE_TRANSPARENT, clear_margin, true, fit_margin, use_mipmaps)
	queue_redraw()
