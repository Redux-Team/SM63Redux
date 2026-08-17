class_name LevelLayer
extends CanvasModulate


## Bounds for [member layer_scale], shared with the level designer's [LDLayer] so what a designer
## can dial in is exactly what a level can express.
const SCALE_MIN: float = 0.1
const SCALE_MAX: float = 4.0


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
## Scales everything on this layer. Rides the objects root rather than the layer itself, so it
## stays independent of the parallax scroll and leaves saved object coordinates meaning what they
## always did - the same place it sits in the editor, so a level plays the way it was built.
@export var layer_scale: Vector2 = Vector2.ONE:
	set(ls):
		layer_scale = ls.clamp(Vector2(SCALE_MIN, SCALE_MIN), Vector2(SCALE_MAX, SCALE_MAX))
		if is_instance_valid(_objects_root):
			_objects_root.scale = layer_scale
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
	_objects_root.scale = layer_scale
	_parallax.add_child(_objects_root)


func get_objects_root() -> Node2D:
	return _objects_root


func _apply_decoration() -> void:
	if not is_instance_valid(_objects_root):
		return
	_objects_root.process_mode = Node.PROCESS_MODE_DISABLED if is_decoration else Node.PROCESS_MODE_INHERIT
