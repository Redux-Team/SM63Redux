@tool
class_name ObjectRegistry

const ROOT: String = "res://game/objects/"

static var _entries: Dictionary[StringName, Entry] = {}
static var _scanned: bool = false
static var _mutex: Mutex = Mutex.new()


static func scan(reload: bool = false) -> void:
	_mutex.lock()
	_entries.clear()
	_scan_directory(ROOT, reload)
	_scanned = true
	_mutex.unlock()


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


static func _scan_directory(path: String, reload: bool = false) -> void:
	for file: String in ResourceLoader.list_directory(path):
		if file.begins_with("_"):
			continue
		
		if file.ends_with("/"):
			_scan_directory(path.path_join(file), reload)
		elif file.get_extension() == "tscn":
			_register(path.path_join(file), reload)


static func _register(path: String, reload: bool = false) -> void:
	var scene: PackedScene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE if reload else ResourceLoader.CACHE_MODE_REUSE) as PackedScene
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
	
	const MAX_TINTED: int = 64
	
	var id: StringName
	var path: String
	var scene: PackedScene
	var display_name: String
	var icon: Texture2D
	var category: StringName
	var group: StringName
	var biome: StringName
	var order: int
	var placement: GameObject.Placement
	var browsable: bool
	var unique: bool
	var flags: int
	var icon_tint: StringName
	var _shape_kind: int = -1
	var _tint_default: Color = Color.WHITE
	var _tint_ready: bool = false
	var _tinted: Dictionary[Color, Texture2D] = {}
	
	
	func _init(scene_path: String, packed: PackedScene, definition: Dictionary) -> void:
		path = scene_path
		scene = packed
		var script: Script = definition.get(&"script")
		id = _read(definition, script, &"id")
		display_name = _read(definition, script, &"display_name")
		icon = _read(definition, script, &"icon")
		category = _read(definition, script, &"category")
		group = _read(definition, script, &"group")
		biome = _read(definition, script, &"biome")
		order = _read(definition, script, &"order")
		placement = _read(definition, script, &"placement")
		browsable = _read(definition, script, &"browsable")
		unique = _read(definition, script, &"unique")
		flags = _read(definition, script, &"flags")
		icon_tint = _read(definition, script, &"icon_tint")
		if display_name.is_empty():
			display_name = String(id).capitalize()
	
	
	func get_shape_kind() -> ObjectShape.Kind:
		if _shape_kind < 0:
			var object: GameObject = scene.instantiate() as GameObject
			_shape_kind = object.shape.get_kind() if object.shape else ObjectShape.Kind.NONE
			object.free()
		
		return _shape_kind as ObjectShape.Kind
	
	
	func get_icon(values: Dictionary = {}) -> Texture2D:
		if icon == null:
			var object: GameObject = scene.instantiate() as GameObject
			icon = object.get_icon()
			object.free()
		
		var color: Color = get_icon_color(values)
		if icon == null or color == Color.WHITE:
			return icon
		
		if not _tinted.has(color):
			if _tinted.size() >= MAX_TINTED:
				_tinted.clear()
			_tinted.set(color, _tint(icon, color))
		return _tinted.get(color)
	
	
	func get_icon_color(values: Dictionary = {}) -> Color:
		if icon_tint.is_empty():
			return Color.WHITE
		
		if not _tint_ready:
			_tint_ready = true
			var object: GameObject = scene.instantiate() as GameObject
			var property: ObjectProperty = object.get_object_property(icon_tint)
			if property:
				_tint_default = property.coerce(null)
			object.free()
		
		return values.get(icon_tint, _tint_default)
	
	
	func has_flag(flag: GameObject.Flag) -> bool:
		return flags & flag != 0
	
	
	static func _tint(texture: Texture2D, color: Color) -> Texture2D:
		var image: Image = texture.get_image()
		image.convert(Image.FORMAT_RGBA8)
		for y: int in image.get_height():
			for x: int in image.get_width():
				image.set_pixel(x, y, image.get_pixel(x, y) * color)
		
		return ImageTexture.create_from_image(image)
	
	
	static func _read(definition: Dictionary, script: Script, property: StringName) -> Variant:
		if definition.has(property):
			return definition.get(property)
		
		return script.get_property_default_value(property)
