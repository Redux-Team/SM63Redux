class_name WaterCheckArea
extends Area2D

signal water_entered
signal water_exited

var area_stack: Dictionary[Area2D, bool]


func is_in_water() -> bool:
	return not area_stack.is_empty()


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	set_deferred(&"monitorable", false)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _on_area_entered(area: Area2D) -> void:
	if area.has_meta(&"water") and area not in area_stack:
		if area_stack.is_empty():
			water_entered.emit()
		
		area_stack.set(area, true)


func _on_area_exited(area: Area2D) -> void:
	if area.has_meta(&"water") and area in area_stack:
		area_stack.erase(area)
		
		if area_stack.is_empty():
			water_exited.emit()


func disable() -> void:
	set_deferred(&"monitoring", false)


func enable() -> void:
	set_deferred(&"monitoring", true)
