class_name LDLayer
extends CanvasGroup


@export_group("Layer")
@export var index: int = 0
@export var is_decoration: bool = false
## The scroll scale of the layer
@export var parallax_scale: Vector2 = Vector2.ONE:
	set(ps):
		if not is_parallaxing and is_instance_valid(_parallax):
			_parallax.scroll_scale = Vector2.ONE
		elif is_instance_valid(_parallax):
			_parallax.scroll_scale = ps
		parallax_scale = ps
@export var modulation: Color = Color.WHITE:
	set(m):
		modulate = (m * _internal_modulation).lightened(0.3)
		modulation = m
@export_group("LD")
## LD exclusive, determines how this layer will be rendered based on whether it is active or not.
@export var is_active: bool = false
## Whether this layer actually does parallaxing, useful toggle for testing and/or editing in the LD.
@export var is_parallaxing: bool = false:
	set(ip):
		if is_instance_valid(_parallax):
			_parallax.scroll_scale = parallax_scale if ip else Vector2.ONE
		is_parallaxing = ip

# Used for layer effects in the editor, should not be changed by the end user.
var _internal_modulation: Color = Color.WHITE:
	set(im):
		modulate = (modulation * im).lightened(0.3)
		_internal_modulation = im

var _parallax: Parallax2D
var _objects_root: Node2D


func _init() -> void:
	_parallax = Parallax2D.new()
	add_child(_parallax)
	_objects_root = Node2D.new()
	_parallax.add_child(_objects_root)


## Returns the root node that holds all placed objects on this layer.
func get_objects_root() -> Node2D:
	return _objects_root


## Returns true if this layer has no placed objects.
func is_empty() -> bool:
	return _objects_root.get_child_count() == 0
