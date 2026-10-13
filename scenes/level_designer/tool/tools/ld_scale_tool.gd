class_name LDScaleTool
extends LDTransformTool

@export var snap_step: float = 0.25
@export var min_scale: float = 0.05


func _get_flag() -> GameObject.Flag:
	return GameObject.Flag.SCALABLE


func _get_action_name() -> String:
	return "Scale Objects"


func _apply(world_position: Vector2) -> void:
	var factor: float = world_position.distance_to(_pivot) / maxf(_start.distance_to(_pivot), 1.0)
	if not Input.is_action_pressed(&"ld_snap_bypass"):
		factor = snappedf(factor, snap_step)
	factor = maxf(factor, min_scale)
	
	for i: int in _objects.size():
		var object: GameObject = _objects.get(i)
		object.scale = _before.get(i).get_scale() * factor
		object.global_position = _pivot + (_before_global.get(i).origin - _pivot) * factor
