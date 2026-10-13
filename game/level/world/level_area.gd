class_name LevelArea
extends Node2D

var uuid: StringName
var area_name: String = ""
var camera_position: Vector2 = Vector2.ZERO
var camera_zoom: float = 1.0
var active_layer: int = 0
var background: Dictionary = {}
var music: Dictionary = {}


static func build(data: AreaData, context: GameObject.Context) -> LevelArea:
	var area: LevelArea = LevelArea.new()
	area.apply_data(data)
	for layer_data: LayerData in data.layers:
		area.insert_layer(LevelLayer.build(layer_data, context))
	
	return area


func apply_data(data: AreaData) -> void:
	uuid = data.uuid
	area_name = data.area_name
	camera_position = data.camera_position
	camera_zoom = data.camera_zoom
	active_layer = data.active_layer
	background = data.background
	music = data.music
	name = area_name.validate_node_name()


func to_data() -> AreaData:
	var data: AreaData = AreaData.new()
	data.uuid = uuid
	data.area_name = area_name
	data.camera_position = camera_position
	data.camera_zoom = camera_zoom
	data.active_layer = active_layer
	data.background = background
	data.music = music
	return data


func capture() -> AreaData:
	var data: AreaData = to_data()
	for layer: LevelLayer in get_layers():
		data.layers.append(layer.capture())
	
	return data


func get_layers() -> Array[LevelLayer]:
	var layers: Array[LevelLayer] = []
	for child: Node in get_children():
		if child is LevelLayer:
			layers.append(child)
	
	return layers


func get_layer(index: int) -> LevelLayer:
	for layer: LevelLayer in get_layers():
		if layer.index == index:
			return layer
	
	return null


func get_or_create_layer(index: int) -> LevelLayer:
	var layer: LevelLayer = get_layer(index)
	if layer == null:
		var data: LayerData = LayerData.create(index)
		layer = LevelLayer.new()
		layer.apply_data(data)
		insert_layer(layer)
	
	return layer


func insert_layer(layer: LevelLayer) -> void:
	add_child(layer)
	sort_layers()


func remove_layer(layer: LevelLayer) -> void:
	remove_child(layer)


func sort_layers() -> void:
	var layers: Array[LevelLayer] = get_layers()
	layers.sort_custom(func(a: LevelLayer, b: LevelLayer) -> bool: return a.index < b.index)
	for i: int in layers.size():
		var layer: LevelLayer = layers.get(i)
		move_child(layer, i)
		layer.z_index = i * LevelLayer.Z_STRIDE


func get_all_objects() -> Array[GameObject]:
	var objects: Array[GameObject] = []
	for layer: LevelLayer in get_layers():
		objects.append_array(layer.get_objects())
	
	return objects


func find_object(object_uuid: StringName) -> GameObject:
	for object: GameObject in get_all_objects():
		if object.uuid == object_uuid:
			return object
	
	return null


func get_layer_of(object: GameObject) -> LevelLayer:
	var current: Node = object.get_parent()
	while current and current != self:
		if current is LevelLayer:
			return current
		current = current.get_parent()
	
	return null
