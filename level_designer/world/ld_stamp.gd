class_name LDStamp
extends Resource


@export var id: String = ""
@export var objects: Array[Dictionary] = []
@export var instances: Array[Dictionary] = []

var preview_texture: ImageTexture = null


func get_instance(unique_id: String) -> Dictionary:
	for instance: Dictionary in instances:
		if instance.get("unique_id", "") == unique_id:
			return instance
	return {}


func has_instance(unique_id: String) -> bool:
	return not get_instance(unique_id).is_empty()


func add_instance(unique_id: String, position: Vector2, layer_index: int) -> Dictionary:
	var instance: Dictionary = {
		"unique_id": unique_id,
		"position": [position.x, position.y],
		"layer_index": layer_index,
		"overrides": {},
	}
	instances.append(instance)
	return instance


func remove_instance(unique_id: String) -> void:
	for i: int in instances.size():
		if instances[i].get("unique_id", "") == unique_id:
			instances.remove_at(i)
			return


func get_full_address(unique_id: String) -> String:
	return id + ":" + unique_id


func is_instance_address(address: String) -> bool:
	return address.contains(":")


func serialize() -> Dictionary:
	return {
		"id": id,
		"objects": objects.duplicate(true),
		"instances": instances.duplicate(true),
	}


static func deserialize(data: Dictionary) -> LDStamp:
	var stamp: LDStamp = LDStamp.new()
	stamp.id = data.get("id", "")
	# assign() (not =) so untyped source arrays (e.g. parsed from JSON) convert into the
	# typed Array[Dictionary] properties instead of erroring.
	stamp.objects.assign(data.get("objects", []).duplicate(true))
	stamp.instances.assign(data.get("instances", []).duplicate(true))
	return stamp
