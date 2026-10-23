class_name ResourceCodec

const UID_KEY: String = "$uid"
const CLASS_KEY: String = "$class"
const VALUES_KEY: String = "$values"
const SKIPPED: Array[StringName] = [
	&"script",
	&"resource_path",
	&"resource_local_to_scene",
	&"resource_scene_unique_id",
]


static func encode(value: Variant) -> Variant:
	if value is Resource:
		return _encode_resource(value)
	
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(encode(item))
		return items
	
	return value


static func decode(value: Variant) -> Variant:
	if value is Dictionary:
		return _decode_resource(value)
	
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(decode(item))
		return items
	
	return value


static func assign(target: Object, property: StringName, value: Variant) -> void:
	var current: Variant = target.get(property)
	if current is Array and (current as Array).is_typed() and value is Array:
		var typed: Array = (current as Array).duplicate()
		typed.clear()
		for item: Variant in value:
			if item != null:
				typed.append(item)
		value = typed
	
	target.set(property, value)


static func _encode_resource(resource: Resource) -> Dictionary:
	if not resource.resource_path.is_empty() and not resource.resource_path.contains("::"):
		var uid: int = ResourceLoader.get_resource_uid(resource.resource_path)
		return {
			UID_KEY: (
					ResourceUID.id_to_text(uid)
					if uid != ResourceUID.INVALID_ID
					else resource.resource_path
			),
		}
	
	var values: Dictionary = {}
	for property: Dictionary in resource.get_property_list():
		var key: StringName = property["name"]
		if (
				int(property["usage"]) & PROPERTY_USAGE_STORAGE
				and not SKIPPED.has(key)
				and not String(key).begins_with("metadata/")
		):
			values[String(key)] = encode(resource.get(key))
	
	return { CLASS_KEY: _class_of(resource), VALUES_KEY: values }


static func _decode_resource(data: Dictionary) -> Variant:
	if data.has(UID_KEY):
		var path: String = data[UID_KEY]
		return load(path) if ResourceLoader.exists(path) else null
	
	if not data.has(CLASS_KEY):
		return data
	
	var resource: Resource = _instantiate(StringName(data[CLASS_KEY]))
	if resource == null:
		return null
	
	var values: Dictionary = data.get(VALUES_KEY, {})
	for key: String in values:
		assign(resource, StringName(key), decode(values[key]))
	
	return resource


static func _class_of(resource: Resource) -> String:
	var script: Script = resource.get_script()
	if script and not script.get_global_name().is_empty():
		return script.get_global_name()
	
	return resource.get_class()


static func _instantiate(class_id: StringName) -> Resource:
	if ClassDB.class_exists(class_id):
		return ClassDB.instantiate(class_id) as Resource
	
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if entry["class"] == class_id:
			return (load(entry["path"]) as Script).new() as Resource
	
	push_warning("ResourceCodec: unknown class '%s'." % class_id)
	return null
