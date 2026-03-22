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
	
	var db: GameObjectDB = GameObjectDB.get_db()
	
	for layer_data: Variant in data["layers"]:
		if not layer_data is Dictionary:
			continue
		var layer_id: String = layer_data.get("layer_id", "a0r0")
		for obj_data: Variant in layer_data.get("objects", []):
			if not obj_data is Dictionary:
				continue
			_instantiate_object(obj_data, layer_id, db)
	
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


func get_objects_in_layer(layer_id: String) -> Array[LevelObject]:
	var result: Array[LevelObject] = []
	for abs_layer: Node in _layers_root.get_children():
		for rel_layer: Node in abs_layer.get_children():
			var layer: LevelLayer = rel_layer as LevelLayer
			if layer and layer.layer_id == layer_id:
				for child: Node in layer.get_children():
					var obj: LevelObject = child as LevelObject
					if obj:
						result.append(obj)
	return result


func get_all_objects() -> Array[LevelObject]:
	var result: Array[LevelObject] = []
	for abs_layer: Node in _layers_root.get_children():
		for rel_layer: Node in abs_layer.get_children():
			for child: Node in rel_layer.get_children():
				var obj: LevelObject = child as LevelObject
				if obj:
					result.append(obj)
	return result


func get_objects_by_id(object_id: String) -> Array[LevelObject]:
	var result: Array[LevelObject] = []
	for obj: LevelObject in get_all_objects():
		if obj.source_object_id == object_id:
			result.append(obj)
	return result


func _instantiate_object(data: Dictionary, layer_id: String, db: GameObjectDB) -> void:
	var object_id: String = data.get("object_id", "")
	if object_id.is_empty():
		return
	
	var game_object: GameObject = _find_game_object(object_id, db)
	if not game_object or not game_object.game_instance:
		return
	
	var instance: Node = game_object.game_instance.instantiate()
	var level_object: LevelObject = instance as LevelObject
	if not level_object:
		push_error("Game instance for '%s' does not extend LevelObject." % object_id)
		instance.queue_free()
		return
	
	var layer: LevelLayer = _get_or_create_layer(layer_id, data)
	layer.add_child(level_object)
	level_object.init_from_data(data)


func _get_or_create_layer(layer_id: String, layer_data: Dictionary) -> LevelLayer:
	var abs_index: int = _parse_absolute_index(layer_id)
	var abs_name: String = "a%d" % abs_index
	
	var abs_layer: Node2D = _layers_root.get_node_or_null(abs_name) as Node2D
	if not abs_layer:
		abs_layer = Node2D.new()
		abs_layer.name = abs_name
		_layers_root.add_child(abs_layer)
	
	for child: Node in abs_layer.get_children():
		var existing: LevelLayer = child as LevelLayer
		if existing and existing.layer_id == layer_id:
			return existing
	
	var layer: LevelLayer = LevelLayer.new()
	layer.name = layer_id
	layer.layer_id = layer_id
	layer.absolute_index = layer_data.get("absolute_index", abs_index)
	layer.relative_index = layer_data.get("relative_index", 0)
	layer.decoration_layer = layer_data.get("decoration_layer", false)
	abs_layer.add_child(layer)
	return layer


func _clear() -> void:
	for child: Node in _layers_root.get_children():
		_layers_root.remove_child(child)
		child.free()


func _find_game_object(id: String, db: GameObjectDB) -> GameObject:
	for obj: GameObject in db.objects.values():
		if obj.id == id:
			return obj
	return null


func _parse_absolute_index(layer_id: String) -> int:
	var regex: RegEx = RegEx.new()
	regex.compile("a(\\d+)")
	var result: RegExMatch = regex.search(layer_id)
	if result:
		return result.get_string(1).to_int()
	return 0
