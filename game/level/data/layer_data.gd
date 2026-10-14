@tool
class_name LayerData
extends RefCounted

var uuid: StringName
var index: int = 0
var layer_name: String = ""
var distance: float = 0.0
var modulation: Color = Color.WHITE
var is_decoration: bool = false
var group: StringName = &""
var objects: Array[ObjectData] = []


static func create(layer_index: int) -> LayerData:
	var data: LayerData = LayerData.new()
	data.uuid = StringName(Packer.generate_uuid())
	data.index = layer_index
	return data


static func from_dict(dict: Dictionary) -> LayerData:
	var data: LayerData = LayerData.new()
	data.uuid = StringName(dict.get("uuid", Packer.generate_uuid()))
	data.index = dict.get("index", 0)
	data.layer_name = dict.get("name", "")
	data.distance = dict.get("distance", 0.0)
	data.modulation = dict.get("modulation", Color.WHITE)
	data.is_decoration = dict.get("is_decoration", false)
	data.group = StringName(dict.get("group", ""))
	for object: Dictionary in dict.get("objects", []):
		data.objects.append(ObjectData.from_dict(object))
	return data


func to_dict() -> Dictionary:
	var object_dicts: Array[Dictionary] = []
	for object: ObjectData in objects:
		object_dicts.append(object.to_dict())
	
	return {
		"uuid": uuid,
		"index": index,
		"name": layer_name,
		"distance": distance,
		"modulation": modulation,
		"is_decoration": is_decoration,
		"group": group,
		"objects": object_dicts,
	}
