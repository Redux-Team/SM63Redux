class_name LevelObjectPolygon
extends LevelObject

## A placed polygon volume with no art of its own. Parses the shape a level designer drew and
## feeds the stitched ring to every collision polygon in [member applied_polygons], so holes
## punched in the editor are honoured in game too.


@export var applied_polygons: Array[CollisionPolygon2D]


var outer_points: PackedVector2Array = PackedVector2Array()
var holes: Array[PackedVector2Array] = []
var topline_overrides: Dictionary = {}


func _on_init() -> void:
	outer_points = Packer.array_to_packed_vec2(data.get("polygon_points"))
	holes = parse_holes(data.get("polygon_holes"))
	
	var overrides: Variant = data.get("topline_forced")
	if overrides is Dictionary:
		topline_overrides = overrides
	
	var ring: PackedVector2Array = TerrainPolygon.build_ring(outer_points, holes)
	for polygon: CollisionPolygon2D in applied_polygons:
		if polygon:
			polygon.polygon = ring


static func parse_holes(raw: Variant) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	if not raw is Array:
		return result
	for entry: Variant in raw:
		if not entry is Array:
			continue
		var points: PackedVector2Array = PackedVector2Array()
		for point: Variant in entry:
			points.append(Packer.array_to_vec2(point))
		if points.size() >= 3:
			result.append(points)
	return result
