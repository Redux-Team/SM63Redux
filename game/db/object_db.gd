@tool
@warning_ignore_start("unused_private_class_variable")
class_name GameObjectDB
extends Resource

static var _inst: GameObjectDB

@export var objects: Dictionary[String, GameObject]
@export_dir var database_dir: String

@export_tool_button("Auto-populate objects") var _populate_objects: Callable:
	get:
		return func() -> void:
			populate_objects(database_dir)

@export_tool_button("Repopulate objects (clean)") var _repopulate_objects: Callable:
	get:
		return func() -> void:
			objects.clear()
			populate_objects.call(database_dir)

@export_category("Debug")
@export_dir var ld_object_database_dir: String
@export_dir var level_object_database_dir: String



@export_tool_button("Find missing LD objects") var _find_missing_ld: Callable:
	get:
		return func() -> void:
			var game_files: Array[String] = _collect_ld_eligible_basenames()
			var skipped: int = objects.size() - game_files.size()
			var ld_files: Array[String] = _collect_basenames(ld_object_database_dir, "tscn")
			var missing: Array[String] = []
			for name: String in game_files:
				if name not in ld_files:
					missing.append(name)
			if missing.is_empty():
				print("No missing LD objects. (skipped %d)" % skipped)
			else:
				print("Missing LD objects (%d, skipped %d):" % [missing.size(), skipped])
				for name: String in missing:
					print("  - ", name)


@export_tool_button("Find missing Level objects") var _find_missing_level: Callable:
	get:
		return func() -> void:
			var game_files: Array[String] = _collect_ld_eligible_basenames()
			var skipped: int = objects.size() - game_files.size()
			var level_files: Array[String] = _collect_basenames(level_object_database_dir, "tscn")
			var missing: Array[String] = []
			for name: String in game_files:
				if name not in level_files:
					missing.append(name)
			if missing.is_empty():
				print("No missing Level objects. (skipped %d)" % skipped)
			else:
				print("Missing Level objects (%d, skipped %d):" % [missing.size(), skipped])
				for name: String in missing:
					print("  - ", name)


@export_tool_button("Find objects without texture") var _find_missing_texture: Callable:
	get:
		return func() -> void:
			var missing: Array[String] = []
			for obj: GameObject in objects.values():
				if not obj.ld_entry_texture:
					missing.append(obj.id)
			if missing.is_empty():
				print("All objects have a texture.")
			else:
				print("Objects without texture (%d):" % missing.size())
				for name: String in missing:
					print("  - ", name)


@export_tool_button("Find proprety-less GameObjects") var _find_empty_objects: Callable:
	get:
		return func() -> void:
			var empty: Array[String] = []
			for obj: GameObject in objects.values():
				if not obj.ld_entry_texture:
					continue
				if obj.ld_properties.is_empty():
					empty.append(obj.id)
			if empty.is_empty():
				print("No empty GameObjects.")
			else:
				print("Empty GameObjects (%d):" % empty.size())
				for name: String in empty:
					print("  - ", name)



static func get_db() -> GameObjectDB:
	if not _inst:
		_inst = load("uid://860ancqo5p43")
	return _inst


func get_from_category(cat: GameObject.ObjectCategory) -> Array[GameObject]:
	var list: Array[GameObject]
	if cat == GameObject.ObjectCategory.ALL:
		return objects.values()
	
	for object: GameObject in objects.values():
		if object.category == cat:
			list.append(object)
	
	return list


func populate_objects(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		var full_path: String = path.path_join(file_name)
		if dir.current_is_dir():
			populate_objects(full_path)
		elif file_name.ends_with(".tres"):
			var res: Resource = load(full_path)
			if res is GameObject:
				var obj_path: String = full_path.trim_prefix(database_dir.trim_suffix("/") + "/").trim_suffix(".tres")
				var category_name: String = obj_path.get_slice("/", 0)
				var obj: GameObject = res as GameObject
				obj.id = file_name.get_basename()
				obj.category = GameObject.get_category_value(category_name)
				obj.ld_object_path = obj_path
				if obj not in objects.values():
					objects.set(obj_path, obj)
		file_name = dir.get_next()


func find_game_object(id: String) -> GameObject:
	for obj: GameObject in objects.values():
		if obj.id == id:
			return obj
	return null


func _collect_ld_eligible_basenames() -> Array[String]:
	var result: Array[String] = []
	for obj: GameObject in objects.values():
		if obj.ld_entry_texture:
			result.append(obj.id)
	return result


func _collect_basenames(path: String, extension: String) -> Array[String]:
	var result: Array[String] = []
	var dir: DirAccess = DirAccess.open(path)
	if not dir:
		return result
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		var full_path: String = path.path_join(file_name)
		if dir.current_is_dir():
			result.append_array(_collect_basenames(full_path, extension))
		elif file_name.ends_with("." + extension):
			result.append(file_name.get_basename())
		file_name = dir.get_next()
	return result
