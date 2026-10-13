@tool
class_name ObjectData
extends RefCounted

var uuid: StringName
var id: StringName
var position: Vector2 = Vector2.ZERO
var rotation: float = 0.0
var scale: Vector2 = Vector2.ONE
var values: Dictionary[StringName, Variant] = {}
var shape: Dictionary = {}


static func create(object_id: StringName) -> ObjectData:
	var data: ObjectData = ObjectData.new()
	data.uuid = StringName(Packer.generate_uuid())
	data.id = object_id
	return data


static func from_dict(dict: Dictionary) -> ObjectData:
	var data: ObjectData = ObjectData.new()
	data.uuid = StringName(dict.get("uuid", Packer.generate_uuid()))
	data.id = StringName(dict.get("id", ""))
	data.position = dict.get("position", Vector2.ZERO)
	data.rotation = dict.get("rotation", 0.0)
	data.scale = dict.get("scale", Vector2.ONE)
	data.values.assign(dict.get("values", {}))
	data.shape = dict.get("shape", {})
	return data


func to_dict() -> Dictionary:
	return {
		"uuid": uuid,
		"id": id,
		"position": position,
		"rotation": rotation,
		"scale": scale,
		"values": values,
		"shape": shape,
	}


func duplicate_with_new_uuid() -> ObjectData:
	var copy: ObjectData = ObjectData.from_dict(to_dict().duplicate(true))
	copy.uuid = StringName(Packer.generate_uuid())
	return copy
