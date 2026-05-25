class_name LevelLayer
extends CanvasModulate


@export var index: int = 0
@export var is_decoration: bool = false:
	set(value):
		is_decoration = value
		_apply_decoration()
@export var parallax_scale: Vector2 = Vector2.ONE:
	set(ps):
		parallax_scale = ps
		if is_instance_valid(_parallax):
			_parallax.scroll_scale = ps
@export var modulation: Color = Color.WHITE:
	set(m):
		modulation = m
		modulate = m


var _parallax: Parallax2D
var _objects_root: Node2D


func _init() -> void:
	_parallax = Parallax2D.new()
	add_child(_parallax)
	_objects_root = Node2D.new()
	_parallax.add_child(_objects_root)


func get_objects_root() -> Node2D:
	return _objects_root


func _apply_decoration() -> void:
	if not is_instance_valid(_objects_root):
		return
	_objects_root.process_mode = Node.PROCESS_MODE_DISABLED if is_decoration else Node.PROCESS_MODE_INHERIT
