class_name LDTelescopingEdit
extends LDWidgetTool


func get_tool_name() -> String:
	return "TelescopingEdit"


func _get_target_objects() -> Array[LDObject]:
	var result: Array[LDObject] = []
	for obj: LDObject in viewport.get_selected_objects():
		if is_instance_valid(obj) and obj is LDObjectTelescoping:
			result.append(obj)
	return result
