class_name LDLayer
extends CanvasGroup


@export_group("Layer")
@export var index: int = 0
## Optional user-facing name; when empty the layer is shown as "Layer <index> (<n> objects)".
@export var layer_name: String = ""
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
		modulation = m
		_apply_modulate()
@export_group("LD")
## LD exclusive, determines how this layer will be rendered based on whether it is active or not.
@export var is_active: bool = false
## Whether this layer actually does parallaxing, useful toggle for testing and/or editing in the LD.
@export var is_parallaxing: bool = false:
	set(ip):
		if is_instance_valid(_parallax):
			_parallax.scroll_scale = parallax_scale if ip else Vector2.ONE
		is_parallaxing = ip

## Editor view toggle: when false the per-layer `modulation` tint is ignored (true texture colors).
var is_modulating: bool = true

# Used for layer effects in the editor, should not be changed by the end user.
var _internal_modulation: Color = Color.WHITE:
	set(im):
		_internal_modulation = im
		_apply_modulate()

var _parallax: Parallax2D
var _objects_root: Node2D


## Recomputes the rendered modulate from the layer tint (when enabled) and the editor's internal
## ghosting modulation.
func _apply_modulate() -> void:
	var base: Color = modulation if is_modulating else Color.WHITE
	modulate = (base * _internal_modulation).lightened(0.3)


## Enables/disables applying this layer's modulation tint (driven by the Modulate view toggle).
func set_modulating(enabled: bool) -> void:
	is_modulating = enabled
	_apply_modulate()


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
