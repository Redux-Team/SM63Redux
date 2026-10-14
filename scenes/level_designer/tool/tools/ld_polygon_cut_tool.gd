class_name LDPolygonCutTool
extends LDPolygonBooleanTool


func _get_action_name() -> String:
	return "Cut Polygon"


func _plan(targets: Array[GameObject], stroke: PackedVector2Array) -> Plan:
	var plan: Plan = Plan.new()
	for target: GameObject in targets:
		var rings: Array = to_layer_rings(target)
		var pieces: Array[Array] = PolygonBoolean.subtract(rings, stroke)
		if pieces.is_empty():
			plan.remove(target)
			continue
		
		if pieces.size() == 1 and pieces.front() == rings:
			continue
		
		plan.output(target, pieces.front(), false)
		for piece: Array in pieces.slice(1):
			plan.output(target, piece, true)
	
	return plan
