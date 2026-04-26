class_name LevelLayer
extends Node2D


var layer_index: int = 0
var base_modulate: Color = Color.WHITE:
	set(value):
		base_modulate = value
		modulate = value
var decoration_layer: bool = false:
	set(value):
		decoration_layer = value
		if is_node_ready():
			_apply_decoration()
var parallax_scale: Vector2 = Vector2.ONE:
	set(value):
		parallax_scale = value
		if is_node_ready():
			_apply_parallax()

var _parallax: Parallax2D
var _content: Node2D


func _ready() -> void:
	_parallax = Parallax2D.new()
	_parallax.name = "Parallax"
	if layer_index == 0:
		_parallax.ignore_camera_scroll = true
	add_child(_parallax)
	_content = Node2D.new()
	_content.name = "Content"
	_parallax.add_child(_content)
	_apply_parallax()
	_apply_decoration()


func get_content_root() -> Node2D:
	return _content


func _apply_parallax() -> void:
	if not _parallax or layer_index == 0:
		return
	_parallax.scroll_scale = parallax_scale


func _apply_decoration() -> void:
	if not _content:
		return
	_content.process_mode = Node.PROCESS_MODE_DISABLED if decoration_layer else Node.PROCESS_MODE_INHERIT
