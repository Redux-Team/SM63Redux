class_name LDLayer
extends CanvasGroup


## The level's own bounds, so the editor can never dial in a distance a level cannot express.
const DISTANCE_MIN: float = LevelLayer.DISTANCE_MIN
const DISTANCE_MAX: float = LevelLayer.DISTANCE_MAX


@export_group("Layer")
@export var index: int = 0
## Optional user-facing name; when empty the layer is shown as "Layer <index> (<n> objects)".
@export var layer_name: String = ""
@export var is_decoration: bool = false
## How far back this layer sits: it drives both the parallax scroll and the scale of everything
## placed on the layer. The scale rides the objects root rather than the layer itself, so it stays
## independent of the parallax scroll and leaves the coordinates objects are placed and saved in
## meaning what they always did.
@export_custom(PROPERTY_HINT_RANGE, "%f,%f,0.1" % [DISTANCE_MIN, DISTANCE_MAX]) var distance: float = 0.0:
	set(d):
		distance = clampf(d, DISTANCE_MIN, DISTANCE_MAX)
		_apply_distance()
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
		is_parallaxing = ip
		_apply_distance()

## Editor view toggle: when false the per-layer `modulation` tint is ignored (true texture colors).
var is_modulating: bool = true

# Used for layer effects in the editor, should not be changed by the end user.
var _internal_modulation: Color = Color.WHITE:
	set(im):
		_internal_modulation = im
		_apply_modulate()

var _parallax: Parallax2D
var _objects_root: Node2D


func _apply_distance() -> void:
	var factor: Vector2 = Vector2.ONE * LevelLayer.scale_from_distance(distance)
	if is_instance_valid(_parallax):
		_parallax.scroll_scale = factor if is_parallaxing else Vector2.ONE
	if is_instance_valid(_objects_root):
		_objects_root.scale = factor


## Recomputes the rendered modulate from the layer tint (when enabled) and the editor's internal
## ghosting modulation.
func _apply_modulate() -> void:
	var base: Color = modulation if is_modulating else Color.WHITE
	modulate = (base * _internal_modulation).lightened(0.3)
	_sync_group_mode()


## A [CanvasGroup] renders its whole subtree to an offscreen buffer so the group modulates as one
## image. That only changes anything when the tint is see-through - an opaque tint multiplies the
## same either way - and the buffer costs a fifth of the editor's frame on a busy layer, so the
## grouping is switched off whenever the layer is fully opaque (which the active layer, and every
## layer with ghosting off, always is).
func _sync_group_mode() -> void:
	RenderingServer.canvas_item_set_canvas_group_mode(
		get_canvas_item(),
		RenderingServer.CANVAS_GROUP_MODE_TRANSPARENT if modulate.a < 1.0 \
			else RenderingServer.CANVAS_GROUP_MODE_DISABLED,
		clear_margin, true, fit_margin, use_mipmaps
	)
	queue_redraw()


## Enables/disables applying this layer's modulation tint (driven by the Modulate view toggle).
func set_modulating(enabled: bool) -> void:
	is_modulating = enabled
	_apply_modulate()


func _init() -> void:
	_parallax = Parallax2D.new()
	add_child(_parallax)
	_objects_root = Node2D.new()
	_parallax.add_child(_objects_root)
	_apply_distance()


## Returns the root node that holds all placed objects on this layer.
func get_objects_root() -> Node2D:
	return _objects_root


## Returns true if this layer has no placed objects.
func is_empty() -> bool:
	return _objects_root.get_child_count() == 0
