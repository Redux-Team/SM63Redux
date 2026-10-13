@tool
class_name ObjectRegistry

const ROOT: String = "res://game/objects/"

static var _entries: Dictionary[StringName, Entry] = {}
static var _scanned: bool = false


static func scan() -> void:
	_entries.clear()
	_scan_directory(ROOT)
	_scanned = true


static func is_scanned() -> bool:
	return _scanned


static func get_entry(object_id: StringName) -> Entry:
	if not _scanned:
		scan()
	
	return _entries.get(object_id)


static func get_scene(object_id: StringName) -> PackedScene:
	var entry: Entry = get_entry(object_id)
	return entry.scene if entry else null


static func spawn(data: ObjectData, context: GameObject.Context) -> GameObject:
	var scene: PackedScene = get_scene(data.id)
	if scene == null:
		push_warning("ObjectRegistry: unknown object id '%s'." % data.id)
		return null
	
	return GameObject.spawn(scene, context, data)


static func get_entries() -> Array[Entry]:
	if not _scanned:
		scan()
	
	var entries: Array[Entry] = []
	entries.assign(_entries.values())
	return entries


static func _scan_directory(path: String) -> void:
	for file: String in ResourceLoader.list_directory(path):
		if file.begins_with("_"):
			continue
		
		if file.ends_with("/"):
			_scan_directory(path.path_join(file))
		elif file.get_extension() == "tscn":
			_register(path.path_join(file))


static func _register(path: String) -> void:
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		return
	
	var definition: Dictionary = _read_root(scene.get_state())
	var script: Script = definition.get(&"script")
	if script == null or not _extends_game_object(script):
		return
	
	var entry: Entry = Entry.new(path, scene, definition)
	if entry.id.is_empty():
		push_error("ObjectRegistry: '%s' has no id." % path)
		return
	
	if _entries.has(entry.id):
		push_error("ObjectRegistry: id '%s' is used by both '%s' and '%s'." % [entry.id, _entries.get(entry.id).path, path])
		return
	
	_entries.set(entry.id, entry)


static func _read_root(state: SceneState) -> Dictionary:
	var definition: Dictionary = {}
	var base: PackedScene = state.get_node_instance(0)
	if base:
		definition = _read_root(base.get_state())
	
	for i: int in state.get_node_property_count(0):
		definition.set(state.get_node_property_name(0, i), state.get_node_property_value(0, i))
	
	return definition


static func _extends_game_object(script: Script) -> bool:
	var current: Script = script
	while current:
		if current.get_global_name() == &"GameObject":
			return true
		current = current.get_base_script()
	
	return false


class Entry:
	extends RefCounted
	
	var id: StringName
	var path: String
	var scene: PackedScene
	var display_name: String
	var icon: Texture2D
	var category: StringName
	var group: StringName
	var browsable: bool
	var unique: bool
	var flags: int
	var _shape_kind: int = -1
	
	
	func _init(scene_path: String, packed: PackedScene, definition: Dictionary) -> void:
		path = scene_path
		scene = packed
		var script: Script = definition.get(&"script")
		id = _read(definition, script, &"id")
		display_name = _read(definition, script, &"display_name")
		icon = _read(definition, script, &"icon")
		category = _read(definition, script, &"category")
		group = _read(definition, script, &"group")
		browsable = _read(definition, script, &"browsable")
		unique = _read(definition, script, &"unique")
		flags = _read(definition, script, &"flags")
		if display_name.is_empty():
			display_name = String(id).capitalize()
	
	
	func get_shape_kind() -> ObjectShape.Kind:
		if _shape_kind < 0:
			var object: GameObject = scene.instantiate() as GameObject
			_shape_kind = object.shape.get_kind() if object.shape else ObjectShape.Kind.NONE
			object.free()
		
		return _shape_kind as ObjectShape.Kind
	
	
	func get_icon() -> Texture2D:
		if icon == null:
			var object: GameObject = scene.instantiate() as GameObject
			icon = object.get_icon()
			object.free()
		
		return icon
	
	
	func has_flag(flag: GameObject.Flag) -> bool:
		return flags & flag != 0
	
	
	static func _read(definition: Dictionary, script: Script, property: StringName) -> Variant:
		if definition.has(property):
			return definition.get(property)
		
		return script.get_property_default_value(property)
