@tool
@warning_ignore_start("unused_private_class_variable")
class_name GameObjectDB
extends Resource

static var _inst: GameObjectDB

@export var objects: Dictionary[String, GameObject]

@export_category("Debug")
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
