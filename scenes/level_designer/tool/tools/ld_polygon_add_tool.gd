class_name LDPolygonAddTool
extends LDPolygonBooleanTool


func _get_action_name() -> String:
	return "Add to Polygon"


func _plan(targets: Array[GameObject], stroke: PackedVector2Array) -> Plan:
	var plan: Plan = Plan.new()
	var primary: GameObject = targets.front()
	var candidates: Array[GameObject] = targets.duplicate()
	for object: GameObject in editor.level_handler.active_layer.get_objects():
		if object.id == primary.id and not candidates.has(object):
			candidates.append(object)
	
	var shapes: Array[Array] = []
	for candidate: GameObject in candidates:
		shapes.append(to_layer_rings(candidate))
	
	var result: Array = PolygonBoolean.union(shapes, stroke)
	var absorbed: Array = result.back()
	if absorbed.is_empty():
		return plan
	
	var merged: Array[GameObject] = []
	for shape: Array in absorbed:
		merged.append(candidates.get(shapes.find(shape)))
	
	var keep: GameObject = primary if merged.has(primary) else merged.front()
	plan.output(keep, result.front(), false)
	for object: GameObject in merged:
		if object != keep:
			plan.remove(object)
	
	return plan
