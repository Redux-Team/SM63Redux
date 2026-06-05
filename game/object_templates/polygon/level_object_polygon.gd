class_name LevelObjectPolygon
extends LevelObject

@export var applied_polygons: Array[Node2D]


var points: PackedVector2Array


func _on_init() -> void:
	var raw_points: Variant = data.get("polygon_points")
	points = Packer.array_to_packed_vec2(raw_points)
	
	for polygon_node: Node2D in applied_polygons:
		polygon_node.set("polygon", points)
