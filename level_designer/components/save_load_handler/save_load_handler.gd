class_name LDSaveLoadHandler
extends LDComponent


const PLAYER_SPAWN_UID: String = "uid://c0fmf7xmrf32i"
const BINARY_EXTENSION: String = ".63r.lvl"
const JSON_EXTENSION: String = ".json"
const FORMAT_VERSION: int = 1
const LAST_SESSION_PATH: String = "user://ld_last_session.json"
const AUTOSAVE_PATH: String = "user://autosave_ld_session"
const PERIODIC_AUTOSAVE_PATH: String = "user://periodic_autosave_ld_session"
const PERIODIC_AUTOSAVE_ENABLED: bool = true
const PERIODIC_AUTOSAVE_INTERVAL: float = 60.0

var level_file_path: String
var method: int = -1 # -1 X, 0 Bin, 1 JSON
var _periodic_autosave_timer: Timer = null


func _enter_tree() -> void:
	if not FileAccess.file_exists(LAST_SESSION_PATH):
		return
	
	var session_raw: String = FileAccess.open(LAST_SESSION_PATH, FileAccess.READ).get_as_text()
	var session: Dictionary = JSON.parse_string(session_raw) if session_raw else {}
	
	level_file_path = session.get("level_file_path", "")
	method = session.get("method", -1)


func _on_ready() -> void:
	# If we are returning from a playtest, deserialize it immediately 
	# and save the session so the cached state becomes our current baseline
	if Singleton.has_meta(&"playtest"):
		_deserialize(Singleton.get_meta(&"playtest"))
		Singleton.remove_meta(&"playtest")
		save_session() 
		return # bypass standard file loading since we just restored the live session

	if PERIODIC_AUTOSAVE_ENABLED:
		_periodic_autosave_timer = Timer.new()
		_periodic_autosave_timer.wait_time = PERIODIC_AUTOSAVE_INTERVAL
		_periodic_autosave_timer.autostart = true
		_periodic_autosave_timer.timeout.connect(_on_periodic_autosave_timeout)
		add_child(_periodic_autosave_timer)
	
	match method:
		0: load_binary(level_file_path)
		1: load_json(level_file_path)
		_: _ensure_player_spawn()


func _on_periodic_autosave_timeout() -> void:
	# Allow autosaving even if the file hasn't been saved to a custom path yet
	# > we want periodic backups of the workspace regardless of method
	var file: FileAccess = FileAccess.open(PERIODIC_AUTOSAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_buffer(var_to_bytes(_serialize()))
		file.close()


func save_binary(path: String) -> Error:
	var data: Dictionary = _serialize()
	var bytes: PackedByteArray = var_to_bytes(data)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	file.close()
	level_file_path = path
	method = 0
	save_session()
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
		level_file_path = path
		method = 0
		save_session()
		LD.get_tool_handler().select_tool("select")
	return err


func load_raw_data(data: Dictionary) -> void:
	_deserialize(data)


func save_json(path: String) -> Error:
	var data: Dictionary = _serialize()
	var json_string: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return FileAccess.get_open_error()
	file.store_string(json_string)
	file.close()
	level_file_path = path
	method = 1
	save_session()
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
		level_file_path = path
		LD.get_tool_handler().select_tool("select")
		method = 1
		save_session()
	return deserialize_err


func get_level_data() -> Dictionary:
	return _serialize()


func save_session() -> void:
	var session_file: FileAccess = FileAccess.open(LAST_SESSION_PATH, FileAccess.WRITE)
	if not session_file:
		return

	# If we have an active, real file path were using on disk, save it normally
	if not level_file_path.is_empty() and FileAccess.file_exists(level_file_path) and level_file_path != AUTOSAVE_PATH:
		session_file.store_string(JSON.stringify({
			"level_file_path": level_file_path,
			"method": method,
		}))
	else:
		# If the file hasn't been saved locally yet, back it up to the emergency state
		var autosave_file: FileAccess = FileAccess.open(AUTOSAVE_PATH, FileAccess.WRITE)
		if autosave_file:
			autosave_file.store_buffer(var_to_bytes(_serialize()))
			autosave_file.close()
		
		session_file.store_string(JSON.stringify({
			"level_file_path": AUTOSAVE_PATH,
			"method": 0, # force binary reading next load to parse the AUTOSAVE_PATH
		}))


func _serialize() -> Dictionary:
	var viewport: LDViewport = LD.get_editor_viewport()
	var layers_data: Array = []
	
	for child: Node in viewport._layers_root.get_children():
		var layer: LDLayer = child as LDLayer
		if not layer:
			continue
		var objects_data: Array = []
		for obj_node: Node in layer.get_content_root().get_children():
			var obj: LDObject = obj_node as LDObject
			if not obj or obj.is_preview:
				continue
			var obj_data: Dictionary = _serialize_object(obj)
			if not obj_data.is_empty():
				objects_data.append(obj_data)
		layers_data.append({
			"layer_index": layer.layer_index,
			"parallax_scale": Packer.vec2_to_array(layer.parallax_scale),
			"decoration": layer.decoration,
			"modulation": Packer.color_to_array(layer.base_modulate),
			"objects": objects_data,
		})
	
	return {
		"version": FORMAT_VERSION,
		"editor": {
			"camera_position": Packer.vec2_to_array(viewport.camera_position),
			"camera_zoom": Packer.vec2_to_array(viewport.camera_zoom),
			"active_layer": viewport.get_active_layer(),
		},
		"layers": layers_data,
	}


func _serialize_object(obj: LDObject) -> Dictionary:
	var game_object: GameObject = find_game_object_for(obj)
	if not game_object:
		return {}
	
	var data: Dictionary = {
		"object_id": game_object.id,
		"position": Packer.vec2_to_array(obj.position),
		"properties": {},
	}
	
	if obj is LDObjectPolygon:
		var poly_obj: LDObjectPolygon = obj as LDObjectPolygon
		if not poly_obj.get_outer_points().is_empty():
			var poly_points: Array = []
			for p: Vector2 in poly_obj.get_outer_points():
				poly_points.append(Packer.vec2_to_array(p))
			data["polygon_points"] = poly_points
		if not poly_obj.get_holes().is_empty():
			var holes_data: Array = []
			for hole: PackedVector2Array in poly_obj.get_holes():
				var hole_arr: Array = []
				for p: Vector2 in hole:
					hole_arr.append(Packer.vec2_to_array(p))
				holes_data.append(hole_arr)
			data["polygon_holes"] = holes_data
	
	var props: Dictionary = obj.get_property_values()
	for key: StringName in props:
		data["properties"][str(key)] = Packer.serialize_json_variant(props[key])
	
	return data


func _deserialize(data: Dictionary) -> Error:
	if not data.has("version") or not data.has("layers"):
		_ensure_player_spawn()
		return ERR_INVALID_DATA
	
	var viewport: LDViewport = LD.get_editor_viewport()
	viewport.clear_selection()
	
	for child: Node in viewport._layers_root.get_children():
		viewport._layers_root.remove_child(child)
		child.free()
	
	var db: GameDB = GameDB.get_db()
	
	for layer_data: Variant in data["layers"]:
		if not layer_data is Dictionary:
			continue
		var layer_index: int = layer_data.get("layer_index", 0)
		var layer: LDLayer = viewport.get_or_create_layer(layer_index)
		var raw_parallax: Variant = layer_data.get("parallax_scale", null)
		if raw_parallax != null:
			layer.parallax_scale = Packer.array_to_vec2(raw_parallax)
		var raw_modulate: Variant = layer_data.get("modulation", null)
		if raw_modulate != null:
			layer.base_modulate = Packer.array_to_color(raw_modulate)
		layer.decoration = layer_data.get("decoration", false)
		for obj_data: Variant in layer_data.get("objects", []):
			if not obj_data is Dictionary:
				continue
			_deserialize_object(obj_data, layer_index, db)
	
	if data.has("editor"):
		var editor_data: Dictionary = data["editor"]
		if editor_data.has("camera_position"):
			viewport.camera_position = Packer.array_to_vec2(editor_data["camera_position"])
		if editor_data.has("camera_zoom"):
			viewport.camera_zoom = Packer.array_to_vec2(editor_data["camera_zoom"])
		if editor_data.has("active_layer"):
			viewport.set_active_layer(editor_data["active_layer"])
	
	_ensure_player_spawn()
	
	return OK


func _ensure_player_spawn() -> void:
	var spawn_scene: PackedScene = load(PLAYER_SPAWN_UID)
	if not spawn_scene:
		return
	
	var game_object: GameObject = _find_game_object_by_scene(spawn_scene)
	if not game_object or not game_object.ld_editor_instance:
		return
	
	var viewport: LDViewport = LD.get_editor_viewport()
	
	for obj: LDObject in viewport.get_all_objects():
		if obj and obj.source_object_id == game_object.id:
			return
	
	var instance: LDObject = game_object.ld_editor_instance.instantiate() as LDObject
	if not instance:
		return
	
	viewport.add_object(instance, Vector2i.ZERO, 0)
	instance.init_properties(game_object)
	instance.place()


func _find_game_object_by_scene(scene: PackedScene) -> GameObject:
	for game_object: GameObject in GameDB.get_db().objects.values():
		if game_object.ld_editor_instance == scene:
			return game_object
	return null


func _deserialize_object(data: Dictionary, layer_index: int, db: GameDB) -> void:
	var object_id: String = data.get("object_id", "")
	if object_id.is_empty():
		return
	
	var game_object: GameObject = find_game_object_by_id(object_id, db)
	if not game_object or not game_object.ld_editor_instance:
		return
	
	var instance: LDObject = game_object.ld_editor_instance.instantiate() as LDObject
	if not instance:
		return
	
	var pos: Vector2 = Packer.array_to_vec2(data.get("position", [0.0, 0.0]))
	LD.get_editor_viewport().add_object(instance, Vector2i(pos), layer_index)
	
	instance.init_properties(game_object)
	
	var props: Dictionary = data.get("properties", {})
	for key: String in props:
		instance.set_property(StringName(key), Packer.deserialize_json_variant((props[key])))
	
	if instance is LDObjectPolygon and data.has("polygon_points"):
		var poly_obj: LDObjectPolygon = instance as LDObjectPolygon
		var points: PackedVector2Array = PackedVector2Array()
		for p: Variant in data["polygon_points"]:
			points.append(Packer.array_to_vec2(p))
		poly_obj.apply_points(points)
	
	if instance is LDObjectPolygon and data.has("polygon_holes"):
		var poly_obj: LDObjectPolygon = instance as LDObjectPolygon
		for hole_data: Variant in data["polygon_holes"]:
			if not hole_data is Array:
				continue
			var hole_points: PackedVector2Array = PackedVector2Array()
			for p: Variant in hole_data:
				hole_points.append(Packer.array_to_vec2(p))
			if hole_points.size() >= 3:
				poly_obj.add_hole(hole_points)
	
	instance.place()


func find_game_object_for(obj: LDObject) -> GameObject:
	if obj.source_object_id.is_empty():
		return null
	return find_game_object_by_id(obj.source_object_id, GameDB.get_db())


func find_game_object_by_id(id: String, db: GameDB) -> GameObject:
	for game_object: GameObject in db.objects.values():
		if game_object.id == id:
			return game_object
	return null
