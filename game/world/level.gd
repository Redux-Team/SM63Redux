class_name Level
extends Node2D

const LEVEL_SCENE: PackedScene = preload("uid://dkjnplx3hhp7q")
const MAX_SCENARIO_COUNT: int = 16


signal loaded

signal yellow_coin_count_updated
signal red_coin_count_updated
signal purple_coin_count_updated

## A shine sprite was collected; carries the shine's scenario id (0 = common).
signal shine_collected(scenario_id: int)
## The player should be removed from the level (e.g. after collecting a kickout shine). The runtime
## decides how (transition out, results screen, ...).
signal kickout_requested


static var _inst: Level

var _yellow_coins_collected: int:
	set(ycc):
		_yellow_coins_collected = ycc
		yellow_coin_count_updated.emit()
var _red_coins_max: Dictionary[String, int]
var _red_coins_collected: Dictionary[String, int]
var _purple_coins_max: Dictionary[String, int]
var _purple_coins_collected: Dictionary[String, int]

var _active_area: LevelArea
var _player: Player
var _loaded: bool = false
var _progress: LevelProgress = LevelProgress.new()

@export var _level_camera: LevelCamera
@export var music_player: AudioStreamPlayer


func _init() -> void:
	_inst = self


static func instantiate() -> Level:
	return LEVEL_SCENE.instantiate()


static func get_instance() -> Level:
	return _inst


static func get_active_area() -> LevelArea:
	return _inst._active_area


static func get_player() -> Player:
	return _inst._player


static func get_camera() -> LevelCamera:
	return _inst._level_camera


func get_yellow_coin_count() -> int:
	return _yellow_coins_collected


func add_yellow_coin(amount: int = 1) -> void:
	_yellow_coins_collected += amount


func set_yellow_coin_count(amount: int) -> void:
	_yellow_coins_collected = amount


func get_red_coin_count(group: String) -> int:
	return _red_coins_collected.get(group, 0)


func set_red_coin_count(group: String, amount: int) -> void:
	_red_coins_collected.set(group, amount)
	red_coin_count_updated.emit()


func get_red_coin_max(group: String) -> int:
	return _red_coins_max.get(group, 0)


func set_red_coin_max(group: String, amount: int) -> void:
	_red_coins_max.set(group, amount)


func get_purple_coin_count(group: String) -> int:
	return _purple_coins_collected.get(group, 0)


func set_purple_coin_count(group: String, amount: int) -> void:
	_purple_coins_collected.set(group, amount)
	purple_coin_count_updated.emit()


func add_purple_coin(group: String, amount: int = 1) -> void:
	_purple_coins_collected.set(group, get_purple_coin_count(group) + amount)
	purple_coin_count_updated.emit()


func get_purple_coin_max(group: String) -> int:
	return _purple_coins_max.get(group, 0)


func add_purple_coin_max(group: String, amount: int = 1) -> void:
	_purple_coins_max.set(group, get_purple_coin_max(group) + amount)


func set_purple_coin_max(group: String, amount: int) -> void:
	_purple_coins_max.set(group, amount)

## The per-run collectible record (shines, star coins, ...) for this level.
func get_progress() -> LevelProgress:
	return _progress


## Records a shine collection in the level progress and notifies listeners. [param scenario_id] is
## the shine's scenario id (0 = common). Re-collecting an already-recorded shine is a no-op.
func collect_shine(scenario_id: int) -> void:
	if _progress.collect(LevelProgress.CATEGORY_SHINE, scenario_id):
		shine_collected.emit(scenario_id)


## Asks the runtime to remove the player from the level (e.g. after a kickout shine).
func request_kickout() -> void:
	kickout_requested.emit()


## Calls the callable once the level finishes loading, or calls it immediately if it
## already loaded.
func on_load(callable: Callable, args: Array = []) -> void:
	if _loaded:
		callable.callv(args)
	else:
		loaded.connect(func() -> void: callable.callv(args), CONNECT_ONE_SHOT)


func is_loaded() -> bool:
	return _loaded


func load_from_dict(data: Dictionary, scenario_index: int = 0) -> Error:
	if not data.has("version"):
		return ERR_INVALID_DATA

	var normalized: Dictionary = _normalize(data)
	if not normalized.has("areas"):
		return ERR_INVALID_DATA

	_clear()

	_build_background(data)

	# Apply the COMMON baseline, then the chosen numbered scenario's overrides on top: layers,
	# tags and stamps left disabled are simply not spawned.
	var disabled_layers: Dictionary[int, bool] = {}
	var disabled_tags: Dictionary[String, bool] = {}
	var disabled_stamps: Dictionary[String, bool] = {}
	_read_scenario(data, scenario_index, disabled_layers, disabled_tags, disabled_stamps)

	for area_data: Variant in normalized.get("areas", []):
		if not area_data is Dictionary:
			continue
		var current_area: LevelArea = _get_or_create_area(area_data.get("name", "default"))
		for layer_data: Variant in area_data.get("layers", []):
			if not layer_data is Dictionary:
				continue
			if (layer_data.get("objects", []) as Array).is_empty():
				continue
			var layer_index: int = layer_data.get("layer_index", 0)
			if disabled_layers.has(layer_index):
				continue
			var layer: LevelLayer = current_area.get_or_create_layer(layer_index)
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
				if not _scenario_allows(obj_data, disabled_tags):
					continue
				_instantiate_object(obj_data, layer, current_area)

	# Stamps are stored as a definition plus instances; expand each placement into real
	# objects so they exist at runtime (the editor rebuilds them from instances instead).
	_spawn_stamps(data, disabled_layers, disabled_tags, disabled_stamps)

	_loaded = true
	loaded.emit()

	_play_music_when_visible()

	return OK


func _play_music_when_visible() -> void:
	create_tween().tween_callback(music_player.play).set_delay(0.5)


## Builds the saved background (backdrop + parallax layers) into a CanvasLayer behind the
## level, using the same LDBackground.build_into() the editor uses.
func _build_background(data: Dictionary) -> void:
	var existing: Node = get_node_or_null(^"Background")
	if existing:
		existing.free()

	var editor: Variant = data.get("editor", {})
	if not editor is Dictionary:
		return
	var bg_data: Variant = (editor as Dictionary).get("background", {})
	if not bg_data is Dictionary or (bg_data as Dictionary).is_empty():
		return

	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "Background"
	layer.layer = -2
	add_child(layer)
	LDBackgroundDB.resolve(bg_data).build_into(layer)


## Reads the COMMON baseline plus the chosen numbered scenario into "disabled" lookups: a layer,
## tag or stamp left off (by COMMON, then overridden by the scenario) should not spawn.
func _read_scenario(data: Dictionary, scenario_index: int, out_layers: Dictionary[int, bool], out_tags: Dictionary[String, bool], out_stamps: Dictionary[String, bool]) -> void:
	var scenarios: Variant = data.get("scenarios", {})
	if not scenarios is Dictionary:
		return
	_apply_scenario_overrides((scenarios as Dictionary).get("common", {}), out_layers, out_tags, out_stamps)
	if scenario_index <= 0:
		return
	for entry: Variant in (scenarios as Dictionary).get("scenarios", []):
		if entry is Dictionary and int((entry as Dictionary).get("index", 0)) == scenario_index:
			_apply_scenario_overrides(entry, out_layers, out_tags, out_stamps)
			return


## Folds one scenario's overrides into the disabled lookups: value false disables (adds), value
## true re-enables (removes), mirroring the editor's layered COMMON + scenario evaluation.
func _apply_scenario_overrides(scenario: Variant, out_layers: Dictionary[int, bool], out_tags: Dictionary[String, bool], out_stamps: Dictionary[String, bool]) -> void:
	if not scenario is Dictionary:
		return
	for pair: Variant in (scenario as Dictionary).get("layer_overrides", []):
		if pair is Array and (pair as Array).size() == 2:
			if bool(pair[1]):
				out_layers.erase(int(pair[0]))
			else:
				out_layers[int(pair[0])] = true
	for pair: Variant in (scenario as Dictionary).get("tag_overrides", []):
		if pair is Array and (pair as Array).size() == 2:
			if bool(pair[1]):
				out_tags.erase(str(pair[0]))
			else:
				out_tags[str(pair[0])] = true
	for pair: Variant in (scenario as Dictionary).get("stamp_overrides", []):
		if pair is Array and (pair as Array).size() == 2:
			if bool(pair[1]):
				out_stamps.erase(str(pair[0]))
			else:
				out_stamps[str(pair[0])] = true


## True if none of the object's tags were disabled by the active scenario.
func _scenario_allows(obj_data: Dictionary, disabled_tags: Dictionary[String, bool]) -> bool:
	for tag: Variant in obj_data.get("tags", []):
		if disabled_tags.has(str(tag)):
			return false
	return true


## Expands every stamp placement (instance) into concrete level objects, applying the same
## scenario filtering as regular objects.
func _spawn_stamps(data: Dictionary, disabled_layers: Dictionary[int, bool], disabled_tags: Dictionary[String, bool], disabled_stamps: Dictionary[String, bool]) -> void:
	if not is_instance_valid(_active_area):
		return
	var stamps: Variant = data.get("stamps", [])
	if not stamps is Array:
		return

	for stamp_data: Variant in stamps:
		if not stamp_data is Dictionary:
			continue
		if disabled_stamps.has(str((stamp_data as Dictionary).get("id", ""))):
			continue
		var entries: Array = (stamp_data as Dictionary).get("objects", [])
		for instance: Variant in (stamp_data as Dictionary).get("instances", []):
			if not instance is Dictionary:
				continue
			var instance_pos: Vector2 = Packer.array_to_vec2((instance as Dictionary).get("position", [0.0, 0.0]))
			var instance_layer: int = int((instance as Dictionary).get("layer_index", 0))
			for entry: Variant in entries:
				if not entry is Dictionary:
					continue
				var obj_layer: int = instance_layer + int((entry as Dictionary).get("layer_offset", 0))
				if disabled_layers.has(obj_layer):
					continue
				if not _scenario_allows(entry, disabled_tags):
					continue
				var world_pos: Vector2 = instance_pos + Packer.array_to_vec2((entry as Dictionary).get("local_offset", [0.0, 0.0]))
				var spawn_data: Dictionary = (entry as Dictionary).duplicate(true)
				spawn_data["position"] = [world_pos.x, world_pos.y]
				if spawn_data.get("properties") is Dictionary and (spawn_data["properties"] as Dictionary).has("position"):
					spawn_data["properties"]["position"] = [world_pos.x, world_pos.y]
				var layer: LevelLayer = _active_area.get_or_create_layer(obj_layer)
				_instantiate_object(spawn_data, layer, _active_area)


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


func _normalize(data: Dictionary) -> Dictionary:
	if data.has("areas"):
		return data
	
	# auto-convert old format: layers at top level -> wrap in default area
	if data.has("layers"):
		return {
			"version": data.get("version", 1),
			"areas": [{
				"name": "default",
				"layers": data.get("layers", []),
			}],
		}
	
	return data


func _get_or_create_area(area_name: String) -> LevelArea:
	for child: Node in get_children():
		var existing: LevelArea = child as LevelArea
		if existing and existing.area_name == area_name:
			return existing
	
	var new_area: LevelArea = LevelArea.new()
	new_area.area_name = area_name
	new_area.name = area_name
	add_child(new_area)
	
	if not is_instance_valid(_active_area):
		_active_area = new_area
	
	return new_area


func _instantiate_object(data: Dictionary, layer: LevelLayer, _area: LevelArea) -> void:
	var object_id: String = data.get("object_id", "")
	if object_id.is_empty():
		return
	
	var game_object: GameObject = GameDB.get_db().find_game_object(object_id)
	if not game_object or not game_object.get_game_instance():
		return
	
	var instance: Node = game_object.get_game_instance()
	layer.get_objects_root().add_child(instance)
	
	if instance is Player:
		_player = instance
	
	var level_object: LevelObject = instance as LevelObject
	if level_object:
		level_object.init_from_data(data)
		return
	
	var entity: Entity = instance as Entity
	if entity:
		entity.init_from_data(data)


func _clear() -> void:
	for child: Node in get_children():
		var area: LevelArea = child as LevelArea
		if area:
			area.clear()
			remove_child(area)
			area.free()
	_active_area = null
	_player = null
	_loaded = false
	_progress.clear()
