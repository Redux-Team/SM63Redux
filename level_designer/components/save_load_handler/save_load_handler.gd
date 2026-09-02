class_name LDSaveLoadHandler
extends Node


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
## Whether any input at all has arrived since the last periodic autosave. The level only ever
## changes because of something the user did, so an interval with nothing at that end cannot have
## changed it - and serializing a large level just to discover that costs more than a frame.
var _input_since_autosave: bool = true
## The in-flight autosave write, or -1. Encoding and writing are pure data work once the tree has
## been read, so they run on a worker rather than on the frame.
var _autosave_task: int = -1
var _autosave_hash: int = 0
var _has_autosaved: bool = false


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
## Pass the dictionary that was just written where there is one: serializing a large level is not
## cheap and a save would otherwise do it twice.
func _mark_clean(data: Dictionary = {}) -> void:
	Singleton.set_meta(SAVED_HASH_META, content_hash(data if not data.is_empty() else _serialize()))


## Hashes a level dict while ignoring volatile editor view state, so the unsaved-changes check only
## reacts to real content edits. Static so the runtime can compare a playtested level the same way.
## Only the containers a key is stripped from are copied - the layer and object data underneath,
## which is nearly all of a level, is shared, and [method @GlobalScope.hash] recurses into it
## either way.
static func content_hash(data: Dictionary) -> int:
	var copy: Dictionary = data.duplicate()
	
	var editor: Variant = copy.get("editor")
	if editor is Dictionary:
		var editor_copy: Dictionary = (editor as Dictionary).duplicate()
		for key: String in VOLATILE_EDITOR_KEYS:
			editor_copy.erase(key)
		copy["editor"] = editor_copy
	
	var areas: Variant = copy.get("areas")
	if areas is Array:
		var areas_copy: Array = []
		for area_entry: Variant in areas as Array:
			if area_entry is Dictionary:
				var entry_copy: Dictionary = (area_entry as Dictionary).duplicate()
				for key: String in VOLATILE_AREA_KEYS:
					entry_copy.erase(key)
				areas_copy.append(entry_copy)
			else:
				areas_copy.append(area_entry)
		copy["areas"] = areas_copy
	
	var custom: Variant = copy.get("custom_music")
	if custom is Dictionary:
		var custom_copy: Dictionary = (custom as Dictionary).duplicate()
		for id: String in custom_copy.keys():
			var entry: Variant = custom_copy.get(id)
			if entry is Dictionary:
				var entry_copy: Dictionary = (entry as Dictionary).duplicate()
				entry_copy.erase("data")
				custom_copy[id] = entry_copy
		copy["custom_music"] = custom_copy
	
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


func _exit_tree() -> void:
	_flush_autosave()


func _enter_tree() -> void:
	if not FileAccess.file_exists(LAST_SESSION_PATH):
		return
	
	var session_raw: String = FileAccess.open(LAST_SESSION_PATH, FileAccess.READ).get_as_text()
	var session: Dictionary = JSON.parse_string(session_raw) if session_raw else {}
	
	level_file_path = session.get("level_file_path", "")
	method = session.get("method", -1)


func setup() -> void:
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


## Any input marks the level as possibly edited. Deliberately every event rather than only the ones
## that can edit: erring towards an extra autosave is free, erring the other way loses work.
func _input(_event: InputEvent) -> void:
	_input_since_autosave = true


## Backs the workspace up even when it has never been saved to a custom path, so the method the
## level would be written with does not matter here.
func _on_periodic_autosave_timeout() -> void:
	if not _input_since_autosave:
		return
	if _autosave_task != -1:
		if not WorkerThreadPool.is_task_completed(_autosave_task):
			return
		_flush_autosave()
	
	var data: Dictionary = _serialize()
	if data.is_empty():
		return
	_input_since_autosave = false
	
	# Idling with the mouse over the viewport still counts as input, so the level is often
	# unchanged even here; comparing costs a fraction of what writing a megabyte back does.
	var content: int = content_hash(data)
	if _has_autosaved and content == _autosave_hash:
		return
	_autosave_hash = content
	_has_autosaved = true
	
	_autosave_task = WorkerThreadPool.add_task(_write_autosave.bind(data), false, "LD periodic autosave")


## Runs on a worker thread. It only ever touches the dictionary it was handed, which the editor
## drops on the way in and never writes to again, so it needs no locking.
func _write_autosave(data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(PERIODIC_AUTOSAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_buffer(var_to_bytes(data))
		file.close()


## Waits for an in-flight autosave to land, so the editor cannot be torn down mid-write and leave a
## truncated backup behind.
func _flush_autosave() -> void:
	if _autosave_task == -1:
		return
	WorkerThreadPool.wait_for_task_completion(_autosave_task)
	_autosave_task = -1


func save_binary(path: String) -> Error:
	var data: Dictionary = _serialize()
	var binary_path: String = path.get_basename() + ".63rl"
	var err: Error = write_binary(binary_path, data)
	if err != OK:
		return err
	level_file_path = path
	method = 0
	save_session()
	_mark_clean(data)
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
	LDMusicDB.clear_custom()
	
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
	var data: Dictionary = _serialize()
	var err: Error = write_json(path, data)
	if err != OK:
		return err
	level_file_path = path
	method = 1
	save_session()
	_mark_clean(data)
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
		var level_data: Dictionary = _serialize()
		if not level_data.is_empty():
			var autosave_file: FileAccess = FileAccess.open(AUTOSAVE_PATH, FileAccess.WRITE)
			if autosave_file:
				autosave_file.store_buffer(var_to_bytes(level_data))
				autosave_file.close()
		
		session_file.store_string(JSON.stringify({
			"level_file_path": AUTOSAVE_PATH,
			"method": 0, # force binary reading next load to parse the AUTOSAVE_PATH
		}))
	
	file_state_changed.emit()


func _serialize() -> Dictionary:
	var level: LDLevel = LD.get_level()
	var bg_handler: LDBackgroundHandler = LD.get_background_handler()
	if not is_instance_valid(level) or not is_instance_valid(bg_handler):
		return {}
	
	var areas_data: Array = []
	
	# Sync the active area's stored view from the live viewport before serializing.
	if is_instance_valid(LDLevel.get_active_area()):
		LDLevel.get_active_area().store_view()
	
	for area: LDArea in level.get_areas():
		areas_data.append({
			"name": area.area_name,
			"background": bg_handler.serialize_area(area),
			"music": LDMusicPresetDB.serialize_area(area),
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
		"custom_music": LDMusicDB.serialize_custom(),
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
			if obj.has_meta(&"linked_stamp") and not str(obj.get_meta(&"linked_stamp")).is_empty():
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
			"layer_scale": Packer.vec2_to_array(layer.layer_scale),
			"is_decoration": layer.is_decoration,
			"distance": layer.distance,
			"modulation": Packer.color_to_array(layer.modulation),
			"objects": objects_data,
		})
	return layers_data


func _serialize_object(obj: LDObject) -> Dictionary:
	var game_object: GameObject = GameDB.get_object(obj.source_object_id)
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
		if not poly_obj.get_topline_overrides().is_empty():
			data["topline_forced"] = poly_obj.get_topline_overrides().duplicate()
	
	# Walked as parallel key/value arrays rather than keys with a lookup each: this runs for every
	# property of every object in the level on every save, and the second hash per property was
	# costing more than the pair of arrays does.
	var props_out: Dictionary = data.get("properties")
	var props: Dictionary = obj.get_property_values()
	var keys: Array = props.keys()
	var values: Array = props.values()
	for i: int in keys.size():
		props_out.set(str(keys.get(i)), Packer.serialize_json_variant(values.get(i)))
	
	if obj.has_meta(&"tags"):
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
	LDMusicDB.deserialize_custom(normalized.get("custom_music", {}))
	
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
		if entry.has("music"):
			LDMusicPresetDB.apply_to_area(area, entry.get("music"))
		else:
			area.apply_default_music()
		# Per-area editor view (defaults to a fresh ZERO/ONE view for areas that predate it).
		area.camera_position = Packer.array_to_vec2(entry.get("camera_position", [0.0, 0.0]))
		area.camera_zoom = Packer.array_to_vec2(entry.get("camera_zoom", [1.0, 1.0]))
		area._active_index = int(entry.get("active_layer", 0))
		_deserialize_area(entry, area)
		_ensure_player_spawn(area)
		_sanitize_player_layer(area)
	
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
func _deserialize_area(entry: Dictionary, area: LDArea) -> void:
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
		var raw_layer_scale: Variant = layer_data.get("layer_scale", null)
		if raw_layer_scale != null:
			layer.layer_scale = Packer.array_to_vec2(raw_layer_scale)
		var raw_modulate: Variant = layer_data.get("modulation", null)
		if raw_modulate != null:
			layer.modulation = Packer.array_to_color(raw_modulate)
		var derived: float = (1.0 / maxf(layer.parallax_scale.x, LDLayer.SCALE_MIN)) - 1.0
		var distance: float = float(layer_data.get("distance", derived))
		layer.is_decoration = layer_data.get("is_decoration", false)
		layer.distance = distance
		for obj_data: Variant in layer_data.get("objects", []):
			if not obj_data is Dictionary:
				continue
			_deserialize_object(obj_data, layer_index, area)


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
	var game_object: GameObject = GameDB.get_object("player_mario")
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


func _sanitize_player_layer(area: LDArea) -> void:
	var player_index: int = area.get_player_layer_index()
	for layer: LDLayer in area.layers:
		if layer.index == player_index:
			layer.layer_name = ""
			layer.is_decoration = false
			layer.parallax_scale = Vector2.ONE
			return


func _deserialize_object(data: Dictionary, layer_index: int, area: LDArea) -> void:
	var object_id: String = data.get("object_id", "")
	if object_id.is_empty():
		return
	
	var game_object: GameObject = GameDB.get_object(object_id)
	if not game_object:
		return
	
	var instance: LDObject = game_object.get_editor_instance()
	if not instance:
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
	
	apply_polygon_data(instance, data)
	
	instance.place()
	
	if data.has("tags"):
		var tags: Array[String] = []
		for tag: Variant in data.get("tags", []):
			tags.append(str(tag))
		if not tags.is_empty():
			instance.set_meta(&"tags", tags)


## Restores the shape a polygon object was saved with. Shared by loading, pasting and stamp
## spawning so every route rebuilds the same outline, holes and topline overrides.
func apply_polygon_data(instance: LDObject, data: Dictionary) -> void:
	var poly_obj: LDObjectPolygon = instance as LDObjectPolygon
	if not poly_obj or not data.has("polygon_points"):
		return
	
	poly_obj.apply_points_and_holes(
		Packer.array_to_packed_vec2(data.get("polygon_points")),
		LevelObjectPolygon.parse_holes(data.get("polygon_holes"))
	)
	
	var overrides: Variant = data.get("topline_forced")
	if overrides is Dictionary:
		poly_obj.set_topline_overrides(overrides)
