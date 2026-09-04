class_name LDPathEdit
extends LDWidgetTool


func get_tool_name() -> String:
	return "PathEdit"


func _get_target_objects() -> Array[LDObject]:
	var result: Array[LDObject] = []
	var selected: Array[LDObject] = viewport.get_selected_objects()
	if selected.size() == 1 and selected.front() is LDObjectPath:
		result.append(selected.front())
	return result
