class_name LevelArea
extends Node2D


static var _inst: LevelArea


var area_name: String = "default"
var layers: Array[LevelLayer] = []


func _init() -> void:
	_inst = self


func _exit_tree() -> void:
	if _inst == self:
		_inst = null


static func get_instance() -> LevelArea:
	return _inst


func get_or_create_layer(index: int) -> LevelLayer:
	for layer: LevelLayer in layers:
		if layer.index == index:
			return layer
	
	var new_layer: LevelLayer = LevelLayer.new()
	new_layer.index = index
	add_child(new_layer)
	
	var insert_pos: int = 0
	for i: int in layers.size():
		if layers.get(i).index < index:
			insert_pos = i + 1
	
	move_child(new_layer, insert_pos)
	layers.append(new_layer)
	layers.sort_custom(func(a: LevelLayer, b: LevelLayer) -> bool:
		return a.index < b.index
	)
	
	return new_layer


func get_all_objects() -> Array[LevelObject]:
	var result: Array[LevelObject] = []
	for layer: LevelLayer in layers:
		for child: Node in layer.get_objects_root().get_children():
			var obj: LevelObject = child as LevelObject
			if obj:
				result.append(obj)
	return result


func get_objects_on_layer(index: int) -> Array[LevelObject]:
	var result: Array[LevelObject] = []
	for layer: LevelLayer in layers:
		if layer.index != index:
			continue
		for child: Node in layer.get_objects_root().get_children():
			var obj: LevelObject = child as LevelObject
			if obj:
				result.append(obj)
	return result


func get_objects_by_id(object_id: String) -> Array[LevelObject]:
	var result: Array[LevelObject] = []
	for obj: LevelObject in get_all_objects():
		if obj.source_object_id == object_id:
			result.append(obj)
	return result


func clear() -> void:
	for layer: LevelLayer in layers:
		layer.queue_free()
	layers.clear()
