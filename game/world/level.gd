class_name Level
extends Node2D


signal loaded

signal yellow_coin_count_updated
signal red_coin_count_updated
signal purple_coin_count_updated


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


func _init() -> void:
	_inst = self


static func get_instance() -> Level:
	return _inst


static func get_active_area() -> LevelArea:
	return _inst._active_area


static func get_player() -> Player:
	return _inst._player


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

## Calls the callable once the level finishes loading, or calls it immediately if it
## already loaded.
func on_load(callable: Callable, args: Array = []) -> void:
	if _loaded:
		callable.callv(args)
	else:
		loaded.connect(func() -> void: callable.callv(args), CONNECT_ONE_SHOT)


func load_from_dict(data: Dictionary) -> Error:
	if not data.has("version"):
		return ERR_INVALID_DATA
	
	var normalized: Dictionary = _normalize(data)
	if not normalized.has("areas"):
		return ERR_INVALID_DATA
	
	_clear()
	
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
				_instantiate_object(obj_data, layer, current_area)
	
	_loaded = true
	loaded.emit()
	
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
	if not game_object or not game_object.game_instance:
		return
	
	var instance: Node = game_object.game_instance.instantiate()
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
