class_name LDStamp
extends Resource


@export var id: String = ""
## When true, the stamp is listed in the object browser so it can be placed like an object.
@export var indexable: bool = true
@export var objects: Array[Dictionary] = []
## Placed instances grouped per area (area_name -> Array[Dictionary]). Each area indexes its own
## instances from 0 independently, so instances in different areas never collide.
@export var instances: Dictionary[String, Array] = {}

var preview_texture: ImageTexture = null


## All instances placed in `area_name` (each: { unique_id, position, layer_index, overrides }).
func get_area_instances(area_name: String) -> Array:
	return instances.get(area_name, [])


func get_instance(area_name: String, unique_id: String) -> Dictionary:
	for instance: Dictionary in get_area_instances(area_name):
		if instance.get("unique_id", "") == unique_id:
			return instance
	return {}


func has_instance(area_name: String, unique_id: String) -> bool:
	return not get_instance(area_name, unique_id).is_empty()


## The lowest free instance id within an area (areas index independently from 0).
func next_instance_id(area_name: String) -> String:
	var n: int = 0
	while has_instance(area_name, str(n)):
		n += 1
	return str(n)


func add_instance(area_name: String, unique_id: String, position: Vector2, layer_index: int) -> Dictionary:
	var instance: Dictionary = {
		"unique_id": unique_id,
		"position": [position.x, position.y],
		"layer_index": layer_index,
		"overrides": {},
	}
	if not instances.has(area_name):
		instances[area_name] = []
	instances[area_name].append(instance)
	return instance


func remove_instance(area_name: String, unique_id: String) -> void:
	var arr: Array = instances.get(area_name, [])
	for i: int in arr.size():
		if arr[i].get("unique_id", "") == unique_id:
			arr.remove_at(i)
			break
	if arr.is_empty():
		instances.erase(area_name)


## The address stamped onto each placed object: "stamp_id:area_name:unique_id" (area names and stamp
## ids are sanitised to contain no ":", so this splits back cleanly).
func get_full_address(area_name: String, unique_id: String) -> String:
	return id + ":" + area_name + ":" + unique_id


func serialize() -> Dictionary:
	return {
		"id": id,
		"indexable": indexable,
		"objects": objects.duplicate(true),
		"instances": instances.duplicate(true),
	}


static func deserialize(data: Dictionary) -> LDStamp:
	var stamp: LDStamp = LDStamp.new()
	stamp.id = data.get("id", "")
	stamp.indexable = bool(data.get("indexable", true))
	# assign() (not =) so untyped source arrays (e.g. parsed from JSON) convert into the
	# typed Array[Dictionary] property instead of erroring.
	stamp.objects.assign(data.get("objects", []).duplicate(true))
	stamp._load_instances(data.get("instances", {}))
	return stamp


## Loads instances, migrating the old flat-array format (each instance tagged with an "area_name")
## into the per-area dictionary.
func _load_instances(raw: Variant) -> void:
	instances.clear()
	if raw is Array:
		for entry: Variant in raw:
			if not entry is Dictionary:
				continue
			var inst: Dictionary = (entry as Dictionary).duplicate(true)
			var area_name: String = str(inst.get("area_name", ""))
			inst.erase("area_name")
			if not instances.has(area_name):
				instances[area_name] = []
			instances[area_name].append(inst)
	elif raw is Dictionary:
		for area_name: Variant in (raw as Dictionary):
			var list: Variant = (raw as Dictionary)[area_name]
			if list is Array:
				instances[str(area_name)] = (list as Array).duplicate(true)
