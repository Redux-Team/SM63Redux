@tool
@warning_ignore_start("unused_private_class_variable")
class_name GameObjectDB
extends Resource

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
				var obj_path: String = full_path.trim_prefix(database_dir + "/").get_basename()
				var category_name: String = obj_path.get_slice("/", 0)
				var obj: GameObject = res as GameObject
				obj.name = file_name.get_basename()
				obj.category = GameObject.get_category_value(category_name)
				obj.ld_object_path = obj_path
				if obj not in objects.values():
					objects.set(obj_path, obj)
				#objects[res.name] = res
		file_name = dir.get_next()
