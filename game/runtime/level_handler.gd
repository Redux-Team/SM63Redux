class_name LevelHandler
extends Node


var _root: Node2D
var _layers_root: Node2D


func setup(root: Node2D) -> void:
	_root = root
	_layers_root = Node2D.new()
	_layers_root.name = "Layers"
	_root.add_child(_layers_root)


func load_from_dict(data: Dictionary) -> Error:
	if not data.has("version") or not data.has("layers"):
		return ERR_INVALID_DATA
	
	_clear()
	
	for layer_data: Variant in data["layers"]:
		if not layer_data is Dictionary:
			continue
		var layer_index: int = layer_data.get("layer_index", 0)
		for obj_data: Variant in layer_data.get("objects", []):
			if not obj_data is Dictionary:
				continue
			_instantiate_object(obj_data, layer_index)
	
	return OK


func load_from_binary(path: String) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return FileAccess.get_open_error()
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	var data: Variant = bytes_to_var(bytes)
	if not data is Dictionary:
		return ERR_INVALID_DATA
	return load_from_dict(data)


func load_from_json(path: String) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return FileAccess.get_open_error()
	var json_string: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var err: Error = json.parse(json_string)
	if err != OK:
		return err
	var data: Variant = json.get_data()
	if not data is Dictionary:
		return ERR_INVALID_DATA
	return load_from_dict(data)


func get_objects_in_layer(layer_index: int) -> Array[LevelObject]:
	var result: Array[LevelObject] = []
	var layer: LevelLayer = _get_layer(layer_index)
	if not layer:
		return result
	for child: Node in layer.get_children():
		var obj: LevelObject = child as LevelObject
		if obj:
			result.append(obj)
	return result


func get_all_objects() -> Array[LevelObject]:
	var result: Array[LevelObject] = []
	for child: Node in _layers_root.get_children():
		for obj_node: Node in child.get_children():
			var obj: LevelObject = obj_node as LevelObject
			if obj:
				result.append(obj)
	return result


func get_objects_by_id(object_id: String) -> Array[LevelObject]:
	var result: Array[LevelObject] = []
	for obj: LevelObject in get_all_objects():
		if obj.source_object_id == object_id:
			result.append(obj)
	return result


func _instantiate_object(data: Dictionary, layer_index: int) -> void:
	var object_id: String = data.get("object_id", "")
	if object_id.is_empty():
		return
	
	var game_object: GameObject = GameDB.get_db().find_game_object(object_id)
	if not game_object or not game_object.game_instance:
		return
	
	var instance: Node = game_object.game_instance.instantiate()
	var layer: LevelLayer = _get_or_create_layer(layer_index)
	layer.add_child(instance)
	
	var level_object: LevelObject = instance as LevelObject
	if level_object:
		level_object.init_from_data(data)
		return
	
	var entity: Entity = instance as Entity
	if entity:
		entity.init_from_data(data)


func _get_or_create_layer(layer_index: int) -> LevelLayer:
	var existing: LevelLayer = _get_layer(layer_index)
	if existing:
		return existing
	
	var layer: LevelLayer = LevelLayer.new()
	layer.name = "layer_%d" % layer_index
	layer.layer_index = layer_index
	_layers_root.add_child(layer)
	_sort_layers()
	return layer


func _get_layer(layer_index: int) -> LevelLayer:
	for child: Node in _layers_root.get_children():
		var layer: LevelLayer = child as LevelLayer
		if layer and layer.layer_index == layer_index:
			return layer
	return null


func _sort_layers() -> void:
	var layers: Array[Node] = _layers_root.get_children()
	layers.sort_custom(func(a: Node, b: Node) -> bool:
		var la: LevelLayer = a as LevelLayer
		var lb: LevelLayer = b as LevelLayer
		if not la or not lb:
			return false
		return la.layer_index < lb.layer_index
	)
	for i: int in layers.size():
		_layers_root.move_child(layers[i], i)


func _clear() -> void:
	for child: Node in _layers_root.get_children():
		_layers_root.remove_child(child)
		child.free()
