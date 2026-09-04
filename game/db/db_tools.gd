@warning_ignore_start("unused_private_class_variable")
@tool
class_name GameDBTools
extends Resource

## Editor-side checks over the object database. The database is nothing but the folder tree under
## [constant GameObject.OBJECTS_ROOT], so there is no index to rebuild here: every button re-reads
## the folder, prints a report and changes nothing on disk.


## Where object art lives. Anything under here that nothing points at is a texture that was drawn
## but never turned into something placeable.
const TEXTURE_ROOT: String = "res://assets/textures/objects/"


@export_tool_button("Validate objects") var _validate_objects: Callable:
	get:
		return validate_objects


@export_tool_button("Find textures without an object") var _find_orphan_textures: Callable:
	get:
		return find_orphan_textures


## Re-reads the folder tree and reports every object missing something the level designer or the
## game will ask it for.
func validate_objects() -> void:
	GameDB.refresh()
	
	var ids: Array[String] = GameDB.get_object_ids()
	var problems: Array[String] = []
	
	for id: String in ids:
		var path: String = GameDB.get_object_path(id)
		var obj: GameObject = GameDB.get_object(id)
		
		if not obj:
			problems.append("%s: does not load as a GameObject" % path)
			continue
		# The id is what saved levels refer to, and the scan takes it from the file name, so a
		# stored id that disagrees would silently orphan every instance already placed.
		if obj.id != id:
			problems.append("%s: id is \"%s\" but the file is named \"%s\"" % [path, obj.id, id])
		if not obj.form:
			problems.append("%s: no form, so it builds an empty object" % path)
		if obj.ld_indexable and not obj.get_entry_texture():
			problems.append("%s: shown in the browser but has no entry texture" % path)
		# A name that resolves to nothing costs the object that field silently, so it is worth
		# saying out loud rather than leaving to a warning at load time.
		for shared: String in obj.ld_shared_properties:
			if not LDPropertyLibrary.get_property(StringName(shared)):
				problems.append("%s: no shared property named \"%s\"" % [path, shared])
		problems.append_array(_stale_property_vars(obj, path))
	
	problems.append_array(_library_problems())
	_report("Validated %d objects" % ids.size(), problems)


## A field that says where it applies, on an object whose script also declares a variable of the
## same name, is the shape of a bug: the variable is a leftover from when the game side assigned
## properties by name, so nothing fills it in while the value goes somewhere else entirely. A script
## that takes `_handle_property` into its own hands is doing this deliberately and is left alone.
func _stale_property_vars(obj: GameObject, path: String) -> Array[String]:
	var problems: Array[String] = []
	if not obj.form or obj.form.game_scene_uid.is_empty():
		return problems
	
	var script: Script = _root_script(obj.form.game_scene_uid)
	if not script:
		return problems
	
	var empty: Array[Dictionary] = []
	var base: Script = script.get_base_script()
	var methods: Dictionary[StringName, bool] = _own_names(
		script.get_script_method_list(), base.get_script_method_list() if base else empty)
	if methods.has(&"_handle_property"):
		return problems
	
	var declared: Dictionary[StringName, bool] = _own_names(
		script.get_script_property_list(), base.get_script_property_list() if base else empty)
	
	for prop: LDProperty in obj.get_properties():
		if prop.apply_mode == LDProperty.Apply.NONE or prop.apply_target == prop.key:
			continue
		if declared.has(prop.key):
			problems.append("%s: \"%s\" applies to \"%s\", but the scene's script also declares a \"%s\" variable that nothing will fill in" % [
				path, prop.key, prop.apply_target, prop.key
			])
	
	return problems


func _root_script(scene_uid: String) -> Script:
	if not ResourceLoader.exists(scene_uid):
		return null
	
	return _root_script_of(load(scene_uid) as PackedScene)


## A scene built by inheriting another doesn't restate the script it got from it, so the base is
## followed until one turns up. Without this, every inherited scene is skipped in silence.
func _root_script_of(scene: PackedScene) -> Script:
	if not scene:
		return null
	
	var state: SceneState = scene.get_state()
	if state.get_node_count() == 0:
		return null
	
	for prop_index: int in state.get_node_property_count(0):
		if state.get_node_property_name(0, prop_index) == &"script":
			var script: Script = state.get_node_property_value(0, prop_index) as Script
			if script:
				return script
	
	return _root_script_of(state.get_node_instance(0))


## Both script list calls include everything inherited, so what a script declares for itself is
## what is left once the base script's own list is taken away. Without this every object looks like
## it overrides [method LevelObject._handle_property] and the check above never fires.
func _own_names(own: Array[Dictionary], inherited: Array[Dictionary]) -> Dictionary[StringName, bool]:
	var result: Dictionary[StringName, bool] = {}
	for entry: Dictionary in own:
		result.set(StringName(entry.get("name", "")), true)
	for entry: Dictionary in inherited:
		result.erase(StringName(entry.get("name", "")))
	
	return result


## The library looks a property up by file name while a level saves it under its key, so the two
## disagreeing is a trap: the object asks for one name and the level stores another.
func _library_problems() -> Array[String]:
	var problems: Array[String] = []
	LDPropertyLibrary.refresh()
	for name: StringName in LDPropertyLibrary.get_property_names():
		var prop: LDProperty = LDPropertyLibrary.get_property(name)
		if prop and prop.key != name:
			problems.append("%s%s.tres: file is named \"%s\" but its key is \"%s\"" % [
				LDPropertyLibrary.ROOT, name, name, prop.key
			])
	return problems


## Lists art under [constant TEXTURE_ROOT] that nothing in the database reaches, which is usually a
## decoration that got drawn and imported but never registered.
func find_orphan_textures() -> void:
	GameDB.refresh()
	
	var used: Dictionary[String, bool] = {}
	var seen: Dictionary[int, bool] = {}
	var visited: Dictionary[String, bool] = {}
	
	for id: String in GameDB.get_object_ids():
		var obj: GameObject = GameDB.get_object(id)
		if not obj:
			continue
		
		_record_texture(obj, used, seen)
		# Hand-authored objects keep their art inside their scenes rather than on the data, so a
		# scan that stopped at the resource would report every one of those textures as unused.
		if obj.form:
			_collect_scene_textures(obj.form.ld_scene_uid, used, seen, visited)
			_collect_scene_textures(obj.form.game_scene_uid, used, seen, visited)
	
	var orphans: Array[String] = []
	_collect_orphans(TEXTURE_ROOT, used, orphans)
	
	_report("Scanned %s" % TEXTURE_ROOT, orphans)


## Records the textures a scene keeps, read straight off its saved state so nothing has to be
## instantiated. Nested scenes are followed once each.
func _collect_scene_textures(scene_uid: String, into: Dictionary[String, bool], seen: Dictionary[int, bool], visited: Dictionary[String, bool]) -> void:
	if scene_uid.is_empty() or not ResourceLoader.exists(scene_uid):
		return
	
	var scene: PackedScene = load(scene_uid) as PackedScene
	if not scene or visited.has(scene.resource_path):
		return
	
	visited.set(scene.resource_path, true)
	var state: SceneState = scene.get_state()
	
	for node_index: int in state.get_node_count():
		for prop_index: int in state.get_node_property_count(node_index):
			_record_texture(state.get_node_property_value(node_index, prop_index), into, seen)
		
		var nested: PackedScene = state.get_node_instance(node_index)
		if nested:
			_collect_scene_textures(nested.resource_path, into, seen, visited)


## Marks the art reachable from one value as used: collections are walked through, an atlas is
## unwrapped to the sheet it cuts from, and any other resource is descended into, because art also
## hides in sprite frames, particle materials and shader uniforms. [param seen] keeps a resource
## graph that points back at itself from looping.
func _record_texture(value: Variant, into: Dictionary[String, bool], seen: Dictionary[int, bool]) -> void:
	if value is Array:
		for item: Variant in value as Array:
			_record_texture(item, into, seen)
		return
	
	if value is Dictionary:
		for key: Variant in value as Dictionary:
			_record_texture(key, into, seen)
			_record_texture((value as Dictionary).get(key), into, seen)
		return
	
	# Scripts are resources too, and walking one reaches nothing but source code while poking every
	# getter it declares, so the graph stops at them.
	if value is not Resource or value is Script:
		return
	
	var res: Resource = value
	if seen.has(res.get_instance_id()):
		return
	seen.set(res.get_instance_id(), true)
	
	if res is AtlasTexture:
		_record_texture((res as AtlasTexture).atlas, into, seen)
		return
	
	# A texture with a file of its own is the use being looked for. One saved inside a scene - a
	# CanvasTexture wrapping the real art, say - has no file, so it gets walked like any other
	# resource until the art underneath it turns up.
	if res is Texture2D and not res.resource_path.is_empty() and "::" not in res.resource_path:
		into.set(res.resource_path, true)
		return
	
	for prop: Dictionary in res.get_property_list():
		var prop_name: String = prop.get("name", "")
		if prop_name != "script" and int(prop.get("usage", 0)) & PROPERTY_USAGE_STORAGE:
			_record_texture(res.get(prop_name), into, seen)


func _collect_orphans(path: String, used: Dictionary[String, bool], into: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if not dir:
		return
	
	var directories: PackedStringArray = dir.get_directories()
	directories.sort()
	for sub_dir: String in directories:
		_collect_orphans(path.path_join(sub_dir), used, into)
	
	var files: PackedStringArray = dir.get_files()
	files.sort()
	for file_name: String in files:
		var full_path: String = path.path_join(file_name)
		if file_name.ends_with(".png") and not used.has(full_path):
			into.append(full_path)


func _report(header: String, lines: Array[String]) -> void:
	if lines.is_empty():
		print("%s: nothing to report." % header)
		return
	
	print("%s: %d to look at" % [header, lines.size()])
	for line: String in lines:
		print("  - ", line)
