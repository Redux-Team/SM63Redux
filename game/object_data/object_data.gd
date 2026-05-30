@abstract 
class_name ObjectData
extends Resource


@abstract func setup_ld_object() -> LDObject
@abstract func setup_level_object() -> Node


func _get_placement_tool() -> String:
	return ""


func _get_select_tool() -> String:
	return ""
