class_name LDRotateTool
extends LDTransformTool

@export var snap_degrees: float = 15.0


func _get_flag() -> GameObject.Flag:
	return GameObject.Flag.ROTATABLE


func _get_action_name() -> String:
	return "Rotate Objects"


func _apply(world_position: Vector2) -> void:
	var angle: float = (world_position - _pivot).angle() - (_start - _pivot).angle()
	if not Input.is_action_pressed(&"ld_snap_bypass"):
		angle = snappedf(angle, deg_to_rad(snap_degrees))
	
	for i: int in _objects.size():
		var object: GameObject = _objects.get(i)
		var before: Transform2D = _before_global.get(i)
		object.global_position = _pivot + (before.origin - _pivot).rotated(angle)
		object.global_rotation = before.get_rotation() + angle
