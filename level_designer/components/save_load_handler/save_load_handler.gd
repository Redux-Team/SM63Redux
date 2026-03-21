class_name LDSaveLoadHandler
extends LDComponent


const BINARY_EXTENSION: String = ".63r.lvl"
const JSON_EXTENSION: String = ".json"
const FORMAT_VERSION: int = 1


func save_binary(path: String) -> Error:
	var data: Dictionary = _serialize()
	var bytes: PackedByteArray = var_to_bytes(data)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	file.close()
	return OK


func load_binary(path: String) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return FileAccess.get_open_error()
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	var data: Variant = bytes_to_var(bytes)
	if not data is Dictionary:
		return ERR_INVALID_DATA
	var err: Error = _deserialize(data)
	if err == OK:
		LD.get_tool_handler().select_tool("select")
	return err


func save_json(path: String) -> Error:
	var data: Dictionary = _serialize()
	var json_string: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return FileAccess.get_open_error()
	file.store_string(json_string)
	file.close()
	return OK


func load_json(path: String) -> Error:
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
	var deserialize_err: Error = _deserialize(data)
	if deserialize_err == OK:
		LD.get_tool_handler().select_tool("select")
	return deserialize_err


func _serialize() -> Dictionary:
	var viewport: LDViewport = LD.get_editor_viewport()
	var layers_data: Array = []
	
	for abs_layer: Node in viewport._layers_root.get_children():
		var abs_layer_obj: LDLayer = abs_layer as LDLayer
		if not abs_layer_obj:
			continue
		for rel_layer: Node in abs_layer_obj.get_children():
			var rel_layer_obj: LDLayer = rel_layer as LDLayer
			if not rel_layer_obj:
				continue
			var objects_data: Array = []
			for child: Node in rel_layer_obj.get_children():
				var obj: LDObject = child as LDObject
				if not obj or obj.is_preview:
					continue
				var obj_data: Dictionary = _serialize_object(obj)
				if not obj_data.is_empty():
					objects_data.append(obj_data)
			layers_data.append({
				"layer_id": rel_layer_obj.layer_id,
				"absolute_index": rel_layer_obj.absolute_index,
				"relative_index": rel_layer_obj.relative_index,
				"decoration_layer": rel_layer_obj.decoration_layer,
				"objects": objects_data,
			})
	
	return {
		"version": FORMAT_VERSION,
		"editor": {
			"camera_position": _vec2_to_array(viewport.camera_position),
			"camera_zoom": _vec2_to_array(viewport.camera_zoom),
		},
		"layers": layers_data,
	}


func _serialize_object(obj: LDObject) -> Dictionary:
	var game_object: GameObject = _find_game_object_for(obj)
	if not game_object:
		return {}
	
	var data: Dictionary = {
		"object_id": game_object.id,
		"position": _vec2_to_array(obj.position),
		"properties": {},
	}
	
	if obj is LDObjectPolygon:
		var poly_obj: LDObjectPolygon = obj as LDObjectPolygon
		if poly_obj._polygon and not poly_obj._polygon.polygon.is_empty():
			var poly_points: Array = []
			for p: Vector2 in poly_obj._polygon.polygon:
				poly_points.append(_vec2_to_array(p))
			data["polygon_points"] = poly_points
	
	var props: Dictionary = obj.get_property_values()
	for key: StringName in props:
		data["properties"][str(key)] = _serialize_variant(props[key])
	
	return data


func _deserialize(data: Dictionary) -> Error:
	if not data.has("version") or not data.has("layers"):
		return ERR_INVALID_DATA
	
	var viewport: LDViewport = LD.get_editor_viewport()
	viewport.clear_selection()
	
	for abs_layer: Node in viewport._layers_root.get_children():
		viewport._layers_root.remove_child(abs_layer)
		abs_layer.free()
	
	var db: GameObjectDB = GameObjectDB.get_db()
	
	for layer_data: Variant in data["layers"]:
		if not layer_data is Dictionary:
			continue
		var layer_id: String = layer_data.get("layer_id", "a0r0")
		for obj_data: Variant in layer_data.get("objects", []):
			if not obj_data is Dictionary:
				continue
			_deserialize_object(obj_data, layer_id, db)
	
	if data.has("editor"):
		var editor_data: Dictionary = data["editor"]
		if editor_data.has("camera_position"):
			viewport.camera_position = _array_to_vec2(editor_data["camera_position"])
		if editor_data.has("camera_zoom"):
			viewport.camera_zoom = _array_to_vec2(editor_data["camera_zoom"])
	
	return OK


func _deserialize_object(data: Dictionary, layer_id: String, db: GameObjectDB) -> void:
	var object_id: String = data.get("object_id", "")
	if object_id.is_empty():
		return
	
	var game_object: GameObject = _find_game_object_by_id(object_id, db)
	if not game_object or not game_object.ld_editor_instance:
		return
	
	var instance: LDObject = game_object.ld_editor_instance.instantiate() as LDObject
	if not instance:
		return
	
	var pos: Vector2 = _array_to_vec2(data.get("position", [0.0, 0.0]))
	LD.get_editor_viewport().add_object(instance, Vector2i(pos), layer_id)
	
	instance.init_properties(game_object)
	
	var props: Dictionary = data.get("properties", {})
	for key: String in props:
		instance.set_property(StringName(key), _deserialize_variant(props[key]))
	
	if instance is LDObjectPolygon and data.has("polygon_points"):
		var poly_obj: LDObjectPolygon = instance as LDObjectPolygon
		var points: PackedVector2Array = PackedVector2Array()
		for p: Variant in data["polygon_points"]:
			points.append(_array_to_vec2(p))
		poly_obj.apply_points(points)
	
	instance.place()


func _find_game_object_for(obj: LDObject) -> GameObject:
	if obj.source_object_id.is_empty():
		return null
	return _find_game_object_by_id(obj.source_object_id, GameObjectDB.get_db())


func _find_game_object_by_id(id: String, db: GameObjectDB) -> GameObject:
	for game_object: GameObject in db.objects.values():
		if game_object.id == id:
			return game_object
	return null


func _serialize_variant(value: Variant) -> Variant:
	if value is Vector2:
		return _vec2_to_array(value)
	if value is Vector2i:
		return [value.x, value.y]
	if value is Color:
		return [value.r, value.g, value.b, value.a]
	return value


func _deserialize_variant(value: Variant) -> Variant:
	if value is Array and value.size() == 2:
		return _array_to_vec2(value)
	if value is Array and value.size() == 4:
		return Color(value[0], value[1], value[2], value[3])
	return value


func _vec2_to_array(v: Vector2) -> Array:
	return [v.x, v.y]


func _array_to_vec2(a: Variant) -> Vector2:
	if a is Array and a.size() >= 2:
		return Vector2(float(a[0]), float(a[1]))
	return Vector2.ZERO
