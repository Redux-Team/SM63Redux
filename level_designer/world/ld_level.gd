class_name LDLevel
extends Node2D


static var _inst: LDLevel


var _active_area: LDArea


func _init() -> void:
	_inst = self


## Returns the currently active area.
static func get_active_area() -> LDArea:
	return _inst._active_area


## Sets the active area.
func set_active_area(area: LDArea) -> void:
	_active_area = area


## Returns the active layer of the currently active area.
static func get_active_layer() -> LDLayer:
	return get_active_area().get_active_layer()


## Returns the objects root node of the active layer in the active area.
static func get_active_objects_root() -> Node2D:
	return get_active_area().get_active_layer().get_objects_root()
