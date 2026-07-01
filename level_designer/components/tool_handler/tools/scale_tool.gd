class_name LDScaleTool
extends LDWidgetTool


func get_tool_name() -> String:
	return "Scale"


func _get_target_objects() -> Array[LDObject]:
	var result: Array[LDObject] = []
	for obj: LDObject in viewport.get_selected_objects():
		for prop: LDProperty in obj.get_properties():
			if prop.key == &"scale":
				result.append(obj)
				break
	return result
