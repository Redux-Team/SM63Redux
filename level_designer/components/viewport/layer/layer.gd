class_name LDLayer
extends CanvasGroup


@export var layer_index: int = 0
@export var decoration: bool = false:
	set(value):
		decoration = value
		if is_node_ready():
			_apply_decoration()
@export var parallax_scale: Vector2 = Vector2.ONE:
	set(value):
		parallax_scale = value
		if is_node_ready():
			_apply_parallax()

var base_modulate: Color = Color.WHITE:
	set(bm):
		base_modulate = bm
		_update_modulation()
var visual_modulate: Color = Color.WHITE:
	set(vm):
		visual_modulate = vm
		_update_modulation()

var _parallax: Parallax2D
var _content: Node2D


func _ready() -> void:
	_parallax = Parallax2D.new()
	_parallax.name = "Parallax"
	add_child(_parallax)
	_content = Node2D.new()
	_content.name = "Content"
	_parallax.add_child(_content)
	_apply_parallax()
	_apply_decoration()


func get_content_root() -> Node2D:
	return _content


func _apply_parallax() -> void:
	if not _parallax:
		return
	_parallax.scroll_scale = parallax_scale


func _apply_decoration() -> void:
	if not _content:
		return
	_content.process_mode = Node.PROCESS_MODE_DISABLED if decoration else Node.PROCESS_MODE_INHERIT


func _update_modulation() -> void:
	modulate = Color.WHITE * base_modulate * visual_modulate
