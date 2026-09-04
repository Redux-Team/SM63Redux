@tool
class_name GameDB

## Registry of every placeable object. The folder *is* the database: an object exists because a
## [GameObject] resource sits somewhere under [constant GameObject.OBJECTS_ROOT], its id is that
## file's name, and its browser category and group are the folders above it. There is no generated
## index, so there is nothing to refresh by hand and nothing that can drift out of date - adding a
## file adds an object and deleting one removes it.
##
## A scan only lists directories, so nothing an object references (textures, scenes, styles) is
## touched by it. Resources load the first time something asks for one, which means loading a level
## pulls in the handful of objects it actually places rather than all of them. The object browser
## is the one caller that needs every object, and it goes through [method get_categories].
##
## Files whose name starts with "_" are skipped, so shared sub-resources can sit beside the objects
## that use them.


class GameObjectGroup:
	var _id: String
	var _objects: Array[GameObject] = []
	
	
	func get_name() -> String:
		return _id
	
	
	func get_objects() -> Array[GameObject]:
		return _objects


class GameObjectCategory:
	var _id: String
	var _groups: Array[GameObjectGroup] = []
	
	
	func get_name() -> String:
		return _id
	
	
	func get_groups() -> Array[GameObjectGroup]:
		return _groups


## Object id -> the file it lives in, filled in by the scan and never holding a loaded resource.
static var _paths: Dictionary[String, String] = {}
## Objects loaded so far, kept alive so repeated placements don't re-read the file.
static var _objects: Dictionary[String, GameObject] = {}
## Browser tree, built on first use because grouping and sorting need every object loaded.
static var _tree: Array[GameObjectCategory] = []
static var _scanned: bool = false


## The object with this id, loaded on first use. Null when nothing under
## [constant GameObject.OBJECTS_ROOT] is named after it.
static func get_object(id: String) -> GameObject:
	var cached: GameObject = _objects.get(id)
	if cached:
		return cached
	
	_ensure_scanned()
	var path: String = _paths.get(id, "")
	if path.is_empty():
		return null
	
	var obj: GameObject = load(path) as GameObject
	if obj:
		_objects.set(id, obj)
	
	return obj


## Every known object id, in scan order (alphabetical by path). Costs no resource loads.
static func get_object_ids() -> Array[String]:
	_ensure_scanned()
	var result: Array[String] = []
	result.assign(_paths.keys())
	return result


## The file backing an id, without loading it.
static func get_object_path(id: String) -> String:
	_ensure_scanned()
	return _paths.get(id, "")


## Browser categories, each holding its groups and their objects. Building this loads every object,
## because the browser shows all of them; the level and the game only ever go through
## [method get_object].
static func get_categories() -> Array[GameObjectCategory]:
	if not _tree.is_empty():
		return _tree
	
	_ensure_scanned()
	var categories: Dictionary[String, GameObjectCategory] = {}
	for id: String in _paths:
		var obj: GameObject = get_object(id)
		if not obj:
			continue
		
		if not categories.has(obj.category):
			var category: GameObjectCategory = GameObjectCategory.new()
			category._id = obj.category
			categories.set(obj.category, category)
		
		_get_or_add_group(categories.get(obj.category), _browser_group(obj))._objects.append(obj)
	
	for category: GameObjectCategory in categories.values():
		for group: GameObjectGroup in category._groups:
			group._objects.sort_custom(func(a: GameObject, b: GameObject) -> bool:
				return a.get_index_id() < b.get_index_id()
			)
	
	_tree.assign(categories.values())
	
	return _tree


static func get_category(category_id: String) -> GameObjectCategory:
	for category: GameObjectCategory in get_categories():
		if category._id == category_id:
			return category
	return null


## Category names straight off the folder layout, so the browser's tabs cost no resource loads.
static func get_category_names() -> Array[String]:
	_ensure_scanned()
	var result: Array[String] = []
	for path: String in _paths.values():
		var category: String = path.trim_prefix(GameObject.OBJECTS_ROOT).get_slice("/", 0)
		if category not in result:
			result.append(category)
	return result


## Drops everything and re-reads the folder tree. Only the editor needs this, after objects are
## added or removed while the project is open.
static func refresh() -> void:
	_paths.clear()
	_objects.clear()
	_tree.clear()
	_scanned = false
	_ensure_scanned()


static func _ensure_scanned() -> void:
	if _scanned:
		return
	
	_scanned = true
	_scan(GameObject.OBJECTS_ROOT)


static func _scan(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if not dir:
		return
	
	var directories: PackedStringArray = dir.get_directories()
	directories.sort()
	for sub_dir: String in directories:
		_scan(path.path_join(sub_dir))
	
	var files: PackedStringArray = dir.get_files()
	files.sort()
	for file_name: String in files:
		if file_name.begins_with("_") or not file_name.ends_with(".tres"):
			continue
		
		var id: String = file_name.get_basename()
		var full_path: String = path.path_join(file_name)
		# Two files of the same name are two objects claiming one id, and whichever lost would
		# just vanish from the browser, so say so rather than picking one.
		if _paths.has(id):
			push_error("GameDB: duplicate object id \"%s\" (%s and %s); keeping the first." % [
				id, _paths.get(id), full_path
			])
			continue
		
		_paths.set(id, full_path)


static func _get_or_add_group(category: GameObjectCategory, group_id: String) -> GameObjectGroup:
	for existing: GameObjectGroup in category._groups:
		if existing._id == group_id:
			return existing
	
	var group: GameObjectGroup = GameObjectGroup.new()
	group._id = group_id
	category._groups.append(group)
	
	return group


## An object's browser section is the folder it lives in unless it names one, which is how the
## nature decorations sort themselves by theme out of the single folder they share.
static func _browser_group(obj: GameObject) -> String:
	return obj.ld_group_override if not obj.ld_group_override.is_empty() else obj.group
