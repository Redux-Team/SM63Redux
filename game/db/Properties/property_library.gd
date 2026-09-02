@tool
class_name LDPropertyLibrary

## The shared property definitions, looked up by file name. Same idea as [GameDB]: the folder is
## the library, so a .tres dropped directly under [constant ROOT] is immediately available to every
## object as [member GameObject.ld_shared_properties], and there is no index to keep in step.
##
## Only fields several objects genuinely have in common belong here. A property one object owns is
## written inline on that object instead, where it sits next to the thing that reads it.


const ROOT: String = "res://game/db/Properties/"


static var _properties: Dictionary[StringName, LDProperty] = {}
static var _scanned: bool = false


static func get_property(key: StringName) -> LDProperty:
	_ensure_scanned()
	return _properties.get(key)


## Resolves a list of names, quietly skipping any that no longer exist so a stale reference costs
## one property rather than the whole object.
static func get_properties(keys: PackedStringArray) -> Array[LDProperty]:
	var result: Array[LDProperty] = []
	for key: String in keys:
		var prop: LDProperty = get_property(StringName(key))
		if prop:
			result.append(prop)
		else:
			push_warning("LDPropertyLibrary: no shared property named \"%s\"." % key)
	return result


static func get_property_names() -> Array[StringName]:
	_ensure_scanned()
	var result: Array[StringName] = []
	result.assign(_properties.keys())
	return result


static func refresh() -> void:
	_properties.clear()
	_scanned = false
	_ensure_scanned()


static func _ensure_scanned() -> void:
	if _scanned:
		return
	
	_scanned = true
	var dir: DirAccess = DirAccess.open(ROOT)
	if not dir:
		return
	
	var files: PackedStringArray = dir.get_files()
	files.sort()
	for file_name: String in files:
		if not file_name.ends_with(".tres"):
			continue
		
		var prop: LDProperty = load(ROOT.path_join(file_name)) as LDProperty
		if prop:
			_properties.set(StringName(file_name.get_basename()), prop)
