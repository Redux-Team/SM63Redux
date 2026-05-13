class_name LayerLayerData
extends Resource

@export var index: int = 0
@export var is_decoration: bool = false
@export var parallax_scale: Vector2 = Vector2.ONE
@export var modulation: Color = Color.WHITE
@export var objects: Array[LevelObjectData]


func serialize() -> Dictionary:
	var data: Dictionary = {
		"index": index,
		"is_decoration": is_decoration,
		"parallax_scale": parallax_scale,
		"modulation": modulation,
	}
	var obj_list: Array[Dictionary]
	for object_data: LevelObjectData in objects:
		obj_list.append(object_data.serialize())
	data.set("objects", obj_list)
	
	return data


func deserialize(data: Dictionary) -> void:
	index = data.get(index)
	is_decoration = data.get(is_decoration)
	parallax_scale = data.get(parallax_scale)
	modulation = data.get(modulation)
	objects = data.get(objects)
