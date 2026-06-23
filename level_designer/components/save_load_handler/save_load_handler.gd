class_name LDSaveLoadHandler
extends LDComponent


const BINARY_EXTENSION: String = ".63rl"
const JSON_EXTENSION: String = ".json"
const FORMAT_VERSION: int = 1
const LAST_SESSION_PATH: String = "user://ld_last_session.json"
const AUTOSAVE_PATH: String = "user://autosave_ld_session"
const PERIODIC_AUTOSAVE_PATH: String = "user://periodic_autosave_ld_session"
const PERIODIC_AUTOSAVE_ENABLED: bool = true
const PERIODIC_AUTOSAVE_INTERVAL: float = 60.0
## Singleton meta holding the content hash of the level as last written to disk, so the unsaved-
## changes check survives a playtest (which unloads this handler) and is readable from the runtime.
const SAVED_HASH_META: StringName = &"ld_saved_level_hash"
## Editor view state that gets serialized but shouldn't count as a meaningful change, so merely
## panning, zooming or toggling the view doesn't make the level look "unsaved".
const VOLATILE_EDITOR_KEYS: Array[String] = [
	"active_area", "parallaxing_enabled", "ghosting_enabled", "modulation_enabled",
]
## Per-area view state (now stored on each area) that is likewise volatile for dirty detection.
const VOLATILE_AREA_KEYS: Array[String] = ["camera_position", "camera_zoom", "active_layer"]


signal file_state_changed


var level_file_path: String
var method: int = -1 # -1 X, 0 Bin, 1 JSON
var _periodic_autosave_timer: Timer = null


## True when a real on-disk level file is currently loaded/saved (so "Save" can write
## to it directly rather than prompting for a path).
func has_loaded_file() -> bool:
	return method != -1 and not level_file_path.is_empty() and level_file_path != AUTOSAVE_PATH


## True when the live level differs from the version last written to disk (or was never saved).
func is_dirty() -> bool:
	if not Singleton.has_meta(SAVED_HASH_META):
		return true
	return content_hash(_serialize()) != Singleton.get_meta(SAVED_HASH_META)


## Records the current level as the saved baseline, so it reads as up-to-date until the next edit.
func _mark_clean() -> void:
	Singleton.set_meta(SAVED_HASH_META, content_hash(_serialize()))


## Hashes a level dict while ignoring volatile editor view state, so the unsaved-changes check only
## reacts to real content edits. Static so the runtime can compare a playtested level the same way.
static func content_hash(data: Dictionary) -> int:
	var copy: Dictionary = data.duplicate(true)
	var editor: Variant = copy.get("editor")
	if editor is Dictionary:
		for key: String in VOLATILE_EDITOR_KEYS:
			(editor as Dictionary).erase(key)
	var areas: Variant = copy.get("areas")
	if areas is Array:
		for area_entry: Variant in areas:
			if area_entry is Dictionary:
				for key: String in VOLATILE_AREA_KEYS:
					(area_entry as Dictionary).erase(key)
	return hash(copy)


static func write_binary(path: String, data: Dictionary) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return FileAccess.get_open_error()
	file.store_buffer(var_to_bytes(data))
	file.close()
	return OK


static func write_json(path: String, data: Dictionary) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return OK


## Writes a level dict back to the on-disk file recorded in the last session, marking it clean.
## Returns false when there is no real file to write to (e.g. the level was never saved), so the
## caller can fall back to prompting for a path. Static so a playtest can save without the editor.
static func save_to_session_file(data: Dictionary) -> bool:
	if not FileAccess.file_exists(LAST_SESSION_PATH):
		return false
	var raw: String = FileAccess.open(LAST_SESSION_PATH, FileAccess.READ).get_as_text()
	var session: Variant = JSON.parse_string(raw) if raw else null
	if not session is Dictionary:
		return false
	var path: String = str((session as Dictionary).get("level_file_path", ""))
	var saved_method: int = int((session as Dictionary).get("method", -1))
	if path.is_empty() or path == AUTOSAVE_PATH or saved_method == -1:
		return false
	var err: Error = write_json(path, data) if saved_method == 1 else write_binary(path, data)
	if err == OK:
		Singleton.set_meta(SAVED_HASH_META, content_hash(data))
	return err == OK


## Saves to the currently loaded file using its existing format.
func save_current() -> Error:
	if not has_loaded_file():
		return ERR_UNCONFIGURED
	if method == 1:
		return save_json(level_file_path)
	return save_binary(level_file_path)


func _enter_tree() -> void:
	if not FileAccess.file_exists(LAST_SESSION_PATH):
		return
	
	var session_raw: String = FileAccess.open(LAST_SESSION_PATH, FileAccess.READ).get_as_text()
	var session: Dictionary = JSON.parse_string(session_raw) if session_raw else {}
	
	level_file_path = session.get("level_file_path", "")
	method = session.get("method", -1)


func _on_ready() -> void:
	# Every area should be independently playable, so guarantee a player spawn whenever one becomes
	# active (covers areas added/loaded without one).
	LDLevel._inst.active_area_changed.connect(_ensure_player_spawn)

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
		_:
			_ensure_player_spawn()
			_mark_clean()


func _on_periodic_autosave_timeout() -> void:
	# Allow autosaving even if the file hasn't been saved to a custom path yet
	# > we want periodic backups of the workspace regardless of method
	var file: FileAccess = FileAccess.open(PERIODIC_AUTOSAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_buffer(var_to_bytes(_serialize()))
		file.close()


func save_binary(path: String) -> Error:
	var binary_path: String = path.get_basename() + ".63rl"
	var err: Error = write_binary(binary_path, _serialize())
	if err != OK:
		return err
	level_file_path = path
	method = 0
	save_session()
	_mark_clean()
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
		_mark_clean()
		LD.get_tool_handler().select_tool("select")
	return err


func load_raw_data(data: Dictionary) -> void:
	_deserialize(data)


func reset_level() -> void:
	var viewport: LDViewport = LD.get_editor_viewport()
	var level: LDLevel = LD.get_level()

	viewport.clear_selection()

	# Back to a single fresh area (its default background comes with it).
	level.clear_areas()
	level.add_area("Area 1")
	level.set_active_area_index(0, false)

	# Clear the rest of the level state too, otherwise stamps/tags/scenarios linger.
	LD.get_tag_handler().deserialize_all([])
	LD.get_stamp_handler().deserialize_all([])
	LD.get_scenario_handler().deserialize_all({})

	viewport.camera_position = Vector2.ZERO
	viewport.camera_zoom = Vector2.ONE

	level_file_path = ""
	method = -1
	save_session()

	_ensure_player_spawn()
	_mark_clean()


func save_json(path: String) -> Error:
	var err: Error = write_json(path, _serialize())
	if err != OK:
		return err
	level_file_path = path
	method = 1
	save_session()
	_mark_clean()
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
		_mark_clean()
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

	file_state_changed.emit()


func _serialize() -> Dictionary:
	var level: LDLevel = LD.get_level()
	var bg_handler: LDBackgroundHandler = LD.get_background_handler()
	var areas_data: Array = []

	# Sync the active area's stored view from the live viewport before serializing.
	if is_instance_valid(LDLevel.get_active_area()):
		LDLevel.get_active_area().store_view()

	for area: LDArea in level.get_areas():
		areas_data.append({
			"name": area.area_name,
			"background": bg_handler.serialize_area(area),
			"camera_position": Packer.vec2_to_array(area.camera_position),
			"camera_zoom": Packer.vec2_to_array(area.camera_zoom),
			"active_layer": area._active_index,
			"layers": _serialize_area_layers(area),
		})

	return {
		"version": FORMAT_VERSION,
		"editor": {
			"active_area": level.get_active_index(),
			"parallaxing_enabled": LD.get_ui().get_viewport_handler().is_parallaxing_enabled(),
			"ghosting_enabled": LD.get_ui().get_viewport_handler().is_ghosting_enabled(),
			"modulation_enabled": LD.get_ui().get_viewport_handler().is_modulation_enabled(),
			"hotbar": LD.get_ui().get_hotbar_handler().serialize_slots(),
		},
		"stamps": LD.get_stamp_handler().serialize_all(),
		"tags": LD.get_tag_handler().serialize_all(),
		"scenarios": LD.get_scenario_handler().serialize_all(),
		"areas": areas_data,
	}


## Serializes one area's non-empty layers (dropping throwaway empty/unnamed ones).
func _serialize_area_layers(area: LDArea) -> Array:
	var layers_data: Array = []
	for layer: LDLayer in area.layers:
		var objects_data: Array = []
		for obj_node: Node in layer.get_objects_root().get_children():
			var obj: LDObject = obj_node as LDObject
			if not obj or obj.is_preview:
				continue
			# Linked-stamp instances are rebuilt from their stamp's instances on load,
			# so don't persist them here or they'd be duplicated.
			if not str(obj.get_meta(&"linked_stamp", "")).is_empty():
				continue
			var obj_data: Dictionary = _serialize_object(obj)
			if not obj_data.is_empty():
				objects_data.append(obj_data)
		# Drop throwaway empty layers, but keep named ones so the user's layer setup survives.
		if objects_data.is_empty() and layer.layer_name.is_empty():
			continue
		layers_data.append({
			"layer_index": layer.index,
			"layer_name": layer.layer_name,
			"parallax_scale": Packer.vec2_to_array(layer.parallax_scale),
			"is_decoration": layer.is_decoration,
			"modulation": Packer.color_to_array(layer.modulation),
			"objects": objects_data,
		})
	return layers_data


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
		if not poly_obj.get_topline_forced().is_empty():
			data["topline_forced"] = poly_obj.get_topline_forced().duplicate()
	
	var props: Dictionary = obj.get_property_values()
	for key: StringName in props:
		data["properties"][str(key)] = Packer.serialize_json_variant(props.get(key))

	var tags: Array[String] = LD.get_tag_handler().get_object_tags(obj)
	if not tags.is_empty():
		data["tags"] = tags

	return data


func _deserialize(data: Dictionary) -> Error:
	if not data.has("version"):
		_ensure_player_spawn()
		return ERR_INVALID_DATA
	
	var normalized: Dictionary = _normalize(data)
	if not normalized.has("areas"):
		_ensure_player_spawn()
		return ERR_INVALID_DATA
	
	var viewport: LDViewport = LD.get_editor_viewport()
	var level: LDLevel = LD.get_level()

	viewport.clear_selection()
	level.clear_areas()

	var db: GameDB = GameDB.get_db()

	# Backgrounds used to live globally under editor.background; fall back to it for areas that
	# predate per-area backgrounds.
	var editor_data: Dictionary = normalized.get("editor", {}) if normalized.get("editor", {}) is Dictionary else {}
	var legacy_bg: Variant = editor_data.get("background", null)

	for area_entry: Variant in normalized.get("areas", []):
		if not area_entry is Dictionary:
			continue
		var entry: Dictionary = area_entry
		var area: LDArea = level.add_area(str(entry.get("name", "Area")))
		if entry.has("background"):
			LD.get_background_handler().apply_to_area(area, entry.get("background"))
		elif legacy_bg is Dictionary:
			LD.get_background_handler().apply_to_area(area, legacy_bg)
		else:
			area.apply_default_background()
		# Per-area editor view (defaults to a fresh ZERO/ONE view for areas that predate it).
		area.camera_position = Packer.array_to_vec2(entry.get("camera_position", [0.0, 0.0]))
		area.camera_zoom = Packer.array_to_vec2(entry.get("camera_zoom", [1.0, 1.0]))
		area._active_index = int(entry.get("active_layer", 0))
		_deserialize_area(entry, area, db)
		_ensure_player_spawn(area)

	# A level always has at least one area to edit.
	if level.get_areas().is_empty():
		level.add_area("Area 1")

	var active_area_index: int = clampi(int(editor_data.get("active_area", 0)), 0, level.get_areas().size() - 1)
	# Legacy single-area levels stored the view globally; apply it to the active area.
	var active_area: LDArea = level.get_areas()[active_area_index]
	if editor_data.has("camera_position"):
		active_area.camera_position = Packer.array_to_vec2(editor_data.get("camera_position"))
	if editor_data.has("camera_zoom"):
		active_area.camera_zoom = Packer.array_to_vec2(editor_data.get("camera_zoom"))
	if editor_data.has("active_layer"):
		active_area._active_index = int(editor_data.get("active_layer"))
	# Don't store the (irrelevant) live view into the area being left while loading.
	level.set_active_area_index(active_area_index, false)

	if normalized.has("editor"):
		if editor_data.has("parallaxing_enabled"):
			LD.get_ui().get_viewport_handler().set_parallaxing_enabled(editor_data.get("parallaxing_enabled"))
		if editor_data.has("ghosting_enabled"):
			LD.get_ui().get_viewport_handler().set_ghosting_enabled(editor_data.get("ghosting_enabled"))
		LD.get_ui().get_viewport_handler().set_modulation_enabled(bool(editor_data.get("modulation_enabled", true)))

	# Always restore these, even when the loaded level omits the key, so stale tags/stamps/
	# scenarios from the previous level don't carry over.
	var tags_data: Variant = normalized.get("tags", [])
	LD.get_tag_handler().deserialize_all(tags_data if tags_data is Array else [])

	var stamps_data: Variant = normalized.get("stamps", [])
	LD.get_stamp_handler().deserialize_all(stamps_data if stamps_data is Array else [])
	LD.get_stamp_handler().rehydrate_all()

	# Restore hotbar slots after stamps exist, so stamp slots resolve their preview icons.
	var hotbar_data: Variant = normalized.get("editor", {}).get("hotbar", [])
	if hotbar_data is Array:
		LD.get_ui().get_hotbar_handler().deserialize_slots(hotbar_data)

	var scenarios_data: Variant = normalized.get("scenarios", {})
	LD.get_scenario_handler().deserialize_all(scenarios_data if scenarios_data is Dictionary else {})

	_ensure_player_spawn()

	return OK


## Loads one area entry's layers + objects into the given (already-created) area.
func _deserialize_area(entry: Dictionary, area: LDArea, db: GameDB) -> void:
	for layer_data: Variant in entry.get("layers", []):
		if not layer_data is Dictionary:
			continue
		var layer_name: String = str(layer_data.get("layer_name", ""))
		if (layer_data.get("objects", []) as Array).is_empty() and layer_name.is_empty():
			continue
		var layer_index: int = layer_data.get("layer_index", 0)
		var layer: LDLayer = area.get_or_create_layer(layer_index)
		layer.layer_name = layer_name
		var raw_parallax: Variant = layer_data.get("parallax_scale", null)
		if raw_parallax != null:
			layer.parallax_scale = Packer.array_to_vec2(raw_parallax)
		var raw_modulate: Variant = layer_data.get("modulation", null)
		if raw_modulate != null:
			layer.modulation = Packer.array_to_color(raw_modulate)
		layer.is_decoration = layer_data.get("is_decoration", false)
		for obj_data: Variant in layer_data.get("objects", []):
			if not obj_data is Dictionary:
				continue
			_deserialize_object(obj_data, layer_index, db, area)


func _normalize(data: Dictionary) -> Dictionary:
	if data.has("areas"):
		return data
	if data.has("layers"):
		return {
			"version": data.get("version", 1),
			"editor": data.get("editor", {}),
			"stamps": data.get("stamps", []),
			"tags": data.get("tags", []),
			"scenarios": data.get("scenarios", {}),
			"areas": [{
				"name": "Area 1",
				"layers": data.get("layers", []),
			}],
		}
	return data


func _ensure_player_spawn(area: LDArea = null) -> void:
	var game_object: GameObject = GameDB.get_db().find_game_object("player_mario")
	if not game_object:
		return

	if not area:
		area = LDLevel.get_active_area()

	for obj: LDObject in area.get_all_objects():
		if obj and obj.source_object_id == game_object.id:
			return
	
	var instance: LDObject = game_object.get_editor_instance()
	if not instance:
		return
	
	area.add_object(instance, Vector2i.ZERO, 0)
	instance.init_properties(game_object)
	instance.place()


func _find_game_object_by_scene(scene: PackedScene) -> GameObject:
	for game_object: GameObject in GameDB.get_db().objects.values():
		if game_object.get_editor_instance() == scene:
			return game_object
	return null


func _deserialize_object(data: Dictionary, layer_index: int, db: GameDB, area: LDArea) -> void:
	var object_id: String = data.get("object_id", "")
	if object_id.is_empty():
		return

	var game_object: GameObject = find_game_object_by_id(object_id, db)
	if not game_object or not game_object.get_editor_instance():
		return

	var instance: LDObject = game_object.get_editor_instance()
	if not instance or instance is not LDObject:
		return

	var pos: Vector2 = Packer.array_to_vec2(data.get("position", [0.0, 0.0]))
	area.add_object(instance, Vector2i(pos), layer_index)
	
	instance.init_properties(game_object)
	
	var props: Dictionary = data.get("properties", {})
	for key: String in props:
		# The node position (set above via add_object) is authoritative; a stale "position"
		# property would otherwise snap the object back to its default origin.
		if key == "position":
			continue
		instance.set_property(StringName(key), Packer.deserialize_json_variant(props.get(key)))
	if instance.has_property("position"):
		instance.set_property_no_apply(&"position", pos)
	
	if instance is LDObjectPolygon and data.has("polygon_points"):
		var poly_obj: LDObjectPolygon = instance as LDObjectPolygon
		var points: PackedVector2Array = PackedVector2Array()
		for p: Variant in data.get("polygon_points", []):
			points.append(Packer.array_to_vec2(p))
		poly_obj.apply_points(points)
	
	if instance is LDObjectPolygon and data.has("topline_forced") and data.get("topline_forced") is Dictionary:
		(instance as LDObjectPolygon).set_topline_forced_all(data.get("topline_forced"))

	if instance is LDObjectPolygon and data.has("polygon_holes"):
		var poly_obj: LDObjectPolygon = instance as LDObjectPolygon
		for hole_data: Variant in data.get("polygon_holes", []):
			if not hole_data is Array:
				continue
			var hole_points: PackedVector2Array = PackedVector2Array()
			for p: Variant in hole_data:
				hole_points.append(Packer.array_to_vec2(p))
			if hole_points.size() >= 3:
				poly_obj.add_hole(hole_points)
	
	instance.place()

	if data.has("tags"):
		var tags: Array[String] = []
		for tag: Variant in data.get("tags", []):
			tags.append(str(tag))
		if not tags.is_empty():
			instance.set_meta(&"tags", tags)


func find_game_object_for(obj: LDObject) -> GameObject:
	if obj.source_object_id.is_empty():
		return null
	return find_game_object_by_id(obj.source_object_id, GameDB.get_db())


func find_game_object_by_id(id: String, db: GameDB) -> GameObject:
	for game_object: GameObject in db.objects.values():
		if game_object.id == id:
			return game_object
	return null
