@tool
class_name AreaData
extends RefCounted

var uuid: StringName
var area_name: String = ""
var camera_position: Vector2 = Vector2.ZERO
var camera_zoom: float = 1.0
var active_layer: int = 0
var background: Dictionary = {}
var music: Dictionary = {}
var layers: Array[LayerData] = []


static func create(name: String) -> AreaData:
	var data: AreaData = AreaData.new()
	data.uuid = StringName(Packer.generate_uuid())
	data.area_name = name
	data.layers.append(LayerData.create(0))
	return data


static func from_dict(dict: Dictionary) -> AreaData:
	var data: AreaData = AreaData.new()
	data.uuid = StringName(dict.get("uuid", Packer.generate_uuid()))
	data.area_name = dict.get("name", "")
	data.camera_position = dict.get("camera_position", Vector2.ZERO)
	data.camera_zoom = dict.get("camera_zoom", 1.0)
	data.active_layer = dict.get("active_layer", 0)
	data.background = dict.get("background", {})
	data.music = dict.get("music", {})
	for layer: Dictionary in dict.get("layers", []):
		data.layers.append(LayerData.from_dict(layer))
	return data


func to_dict() -> Dictionary:
	var layer_dicts: Array[Dictionary] = []
	for layer: LayerData in layers:
		layer_dicts.append(layer.to_dict())
	
	return {
		"uuid": uuid,
		"name": area_name,
		"camera_position": camera_position,
		"camera_zoom": camera_zoom,
		"active_layer": active_layer,
		"background": background,
		"music": music,
		"layers": layer_dicts,
	}
