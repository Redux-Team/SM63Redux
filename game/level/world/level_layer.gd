class_name LevelLayer
extends Node2D

const DISTANCE_MIN: float = -0.8
const DISTANCE_MAX: float = 9.0
const Z_STRIDE: int = 16
const DISABLED_ALPHA: float = 0.3

var uuid: StringName
var index: int = 0
var layer_name: String = ""
var group: StringName = &""
var is_decoration: bool = false:
	set(value):
		is_decoration = value
		_apply_decoration()
var silhouette: bool = true
var editor_visible: bool = true:
	set(value):
		editor_visible = value
		_apply_visibility()
var group_visible: bool = true:
	set(value):
		group_visible = value
		_apply_visibility()
var enabled: bool = true:
	set(value):
		enabled = value
		_apply_modulate()
var distance: float = 0.0:
	set(value):
		distance = clampf(value, DISTANCE_MIN, DISTANCE_MAX)
		_apply_distance()
var modulation: Color = Color.WHITE:
	set(value):
		modulation = value
		_apply_modulate()
var tint: Color = Color.WHITE:
	set(value):
		tint = value
		_apply_modulate()
var focus_distance: float = 0.0:
	set(value):
		focus_distance = clampf(value, DISTANCE_MIN, DISTANCE_MAX)
		_apply_distance()
var modulation_enabled: bool = true:
	set(value):
		modulation_enabled = value
		_apply_modulate()
var group_modulation: Color = Color.WHITE:
	set(value):
		group_modulation = value
		_apply_modulate()
var group_distance: float = 0.0:
	set(value):
		group_distance = value
		_apply_distance()
var group_decoration: bool = false:
	set(value):
		group_decoration = value
		_apply_decoration()
var group_enabled: bool = true:
	set(value):
		group_enabled = value
		_apply_modulate()

var _parallax: Parallax2D
var _objects_root: Node2D


static func scale_from_distance(layer_distance: float) -> float:
	return 1.0 / (1.0 + clampf(layer_distance, DISTANCE_MIN, DISTANCE_MAX))


static func build(data: LayerData, context: GameObject.Context) -> LevelLayer:
	var layer: LevelLayer = LevelLayer.new()
	layer.apply_data(data)
	for object_data: ObjectData in data.objects:
		var object: GameObject = ObjectRegistry.spawn(object_data, context)
		if object:
			layer.add_object(object)
	
	return layer


func _init() -> void:
	_parallax = Parallax2D.new()
	add_child(_parallax)
	_objects_root = Node2D.new()
	_objects_root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	_parallax.add_child(_objects_root)
	_apply_distance()


func _enter_tree() -> void:
	get_viewport().size_changed.connect(_apply_distance)
	_apply_distance()


func _exit_tree() -> void:
	get_viewport().size_changed.disconnect(_apply_distance)


func apply_data(data: LayerData) -> void:
	uuid = data.uuid
	index = data.index
	layer_name = data.layer_name
	distance = data.distance
	modulation = data.modulation
	is_decoration = data.is_decoration
	silhouette = data.silhouette
	enabled = data.enabled
	editor_visible = data.editor_visible
	group = data.group
	name = "Layer%d" % index


func to_data() -> LayerData:
	var data: LayerData = LayerData.new()
	data.uuid = uuid
	data.index = index
	data.layer_name = layer_name
	data.distance = distance
	data.modulation = modulation
	data.is_decoration = is_decoration
	data.silhouette = silhouette
	data.enabled = enabled
	data.editor_visible = editor_visible
	data.group = group
	return data


func capture() -> LayerData:
	var data: LayerData = to_data()
	for object: GameObject in get_objects():
		data.objects.append(object.to_data())
	
	return data


func get_objects_root() -> Node2D:
	return _objects_root


func get_objects() -> Array[GameObject]:
	var objects: Array[GameObject] = []
	for child: Node in _objects_root.get_children():
		if child is GameObject:
			objects.append(child)
	
	return objects


func add_object(object: GameObject, at: int = -1) -> void:
	_objects_root.add_child(object)
	if at >= 0:
		_objects_root.move_child(object, at)


func remove_object(object: GameObject) -> int:
	var at: int = object.get_index()
	_objects_root.remove_child(object)
	return at


func get_display_name() -> String:
	return layer_name if not layer_name.is_empty() else "Layer %d" % index


func inherit(group_data: Dictionary) -> void:
	group_modulation = group_data.get("modulation", Color.WHITE)
	group_distance = group_data.get("distance", 0.0)
	group_decoration = group_data.get("is_decoration", false)
	group_enabled = group_data.get("enabled", true)
	group_visible = group_data.get("visible", true)


func is_effective_visible() -> bool:
	return editor_visible and group_visible


func is_effective_enabled() -> bool:
	return enabled and group_enabled


func is_effective_decoration() -> bool:
	return is_decoration or group_decoration


func get_effective_distance() -> float:
	return distance + (group_distance if is_effective_decoration() else 0.0)


func _apply_decoration() -> void:
	_objects_root.process_mode = Node.PROCESS_MODE_DISABLED if is_effective_decoration() else Node.PROCESS_MODE_INHERIT
	_apply_distance()


func _apply_distance() -> void:
	var factor: Vector2 = Vector2.ONE * scale_from_distance(get_effective_distance()) / scale_from_distance(focus_distance)
	var half_view: Vector2 = get_viewport_rect().size / 2.0 if is_inside_tree() else Vector2.ZERO
	_parallax.scroll_scale = factor
	_parallax.scroll_offset = (Vector2.ONE - factor) * half_view
	_objects_root.scale = factor
	var screen_offset: Vector2 = _parallax.screen_offset
	_parallax.screen_offset = screen_offset + Vector2.ONE
	_parallax.screen_offset = screen_offset


func _apply_visibility() -> void:
	visible = is_effective_visible()


func _apply_modulate() -> void:
	modulate = (modulation * group_modulation if modulation_enabled else Color.WHITE) * tint * Color(1.0, 1.0, 1.0, 1.0 if is_effective_enabled() else DISABLED_ALPHA)
