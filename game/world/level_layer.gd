class_name LevelLayer
extends CanvasModulate


## Bounds for [member distance], shared with the level designer's [LDLayer] so what a designer
## can dial in is exactly what a level can express.
const DISTANCE_MIN: float = -0.8
const DISTANCE_MAX: float = 9.0


@export var index: int = 0
@export var is_decoration: bool = false:
	set(value):
		is_decoration = value
		_apply_decoration()
## How far back this layer sits: it drives both the parallax scroll and the scale of everything
## placed on the layer. The scale rides the objects root rather than the layer itself, so it stays
## independent of the parallax scroll and leaves saved object coordinates meaning what they always
## did - the same place it sits in the editor, so a level plays the way it was built.
@export_custom(PROPERTY_HINT_RANGE, "%f,%f,0.1" % [DISTANCE_MIN, DISTANCE_MAX]) var distance: float = 0.0:
	set(d):
		distance = clampf(d, DISTANCE_MIN, DISTANCE_MAX)
		_apply_distance()
@export var modulation: Color = Color.WHITE:
	set(m):
		modulation = m
		modulate = m


var _parallax: Parallax2D
var _objects_root: Node2D


static func scale_from_distance(dist: float) -> float:
	return 1.0 / (1.0 + clampf(dist, DISTANCE_MIN, DISTANCE_MAX))


static func distance_from_scale(layer_scale: float) -> float:
	return clampf((1.0 / maxf(layer_scale, 0.01)) - 1.0, DISTANCE_MIN, DISTANCE_MAX)


## Reads a layer's distance out of saved data, porting levels written before parallax and scale
## were folded into it: those layers carried their own scale, which is the distance they now mean.
static func distance_from_data(data: Dictionary) -> float:
	var legacy: Variant = data.get("layer_scale", data.get("parallax_scale", null))
	if legacy != null and not data.get("is_decoration", false):
		return distance_from_scale(Packer.array_to_vec2(legacy).x)
	return clampf(float(data.get("distance", 0.0)), DISTANCE_MIN, DISTANCE_MAX)


func _init() -> void:
	_parallax = Parallax2D.new()
	add_child(_parallax)
	_objects_root = Node2D.new()
	_parallax.add_child(_objects_root)
	_apply_distance()


func get_objects_root() -> Node2D:
	return _objects_root


func _apply_distance() -> void:
	var factor: Vector2 = Vector2.ONE * scale_from_distance(distance)
	if is_instance_valid(_parallax):
		_parallax.scroll_scale = factor
	if is_instance_valid(_objects_root):
		_objects_root.scale = factor


func _apply_decoration() -> void:
	if not is_instance_valid(_objects_root):
		return
	_objects_root.process_mode = Node.PROCESS_MODE_DISABLED if is_decoration else Node.PROCESS_MODE_INHERIT
