@tool
class_name CollisionTrait
extends ObjectTrait

## Gives an object a solid body in the game. Nothing is built unless an object asks for this, so the
## great majority of decorations carry no physics nodes at all rather than a body that gets freed
## again on load.
##
## With neither a shape nor a polygon set, the object's own default is used - for a sprite, its
## texture's rect.


const COLLISION_LAYER: int = 514


@export var shape: Shape2D
@export var polygon: PackedVector2Array
@export var offset: Vector2

@export_group("One Way", "one_way")
@export var one_way: bool = true
@export var one_way_margin: float = 1.0


func build_game(obj: Node) -> void:
	var level_object: LevelObject = obj as LevelObject
	if not level_object or level_object.body:
		return
	
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "Body"
	body.collision_layer = COLLISION_LAYER
	body.add_child(_build_collider(level_object))
	level_object.add_child(body)
	level_object.body = body


func _build_collider(level_object: LevelObject) -> Node2D:
	if not polygon.is_empty():
		var collision_polygon: CollisionPolygon2D = CollisionPolygon2D.new()
		collision_polygon.polygon = polygon
		collision_polygon.position = offset
		return collision_polygon
	
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.shape = shape if shape else level_object.get_default_collision_shape()
	collision_shape.position = offset
	collision_shape.one_way_collision = one_way
	collision_shape.one_way_collision_margin = one_way_margin
	
	return collision_shape
