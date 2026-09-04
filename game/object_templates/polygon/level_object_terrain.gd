@tool
class_name LevelObjectTerrain
extends LevelObjectPolygon

## The in-game half of a polygon object. Renders through the same [PolygonSurface] the level
## designer previews with, and turns the shape into collision: a filled body, one-way platforms
## along the toplines, or nothing at all.


@export var polygon_data: PolygonForm:
	set(d):
		polygon_data = d
		if surface:
			surface.data = d

@export_group("Internal")
@export var surface: PolygonSurface
@export var collision: CollisionPolygon2D
@export var static_body: StaticBody2D


var rng_seed: int = 0
var base_style: String = ""
var topline_style: String = ""
var decoration_set: String = ""
var decorations_enabled: bool = true
var collision_mode: String = ""

var _semisolid_shapes: Array[CollisionShape2D] = []


static func from_data(object_data: ObjectForm) -> LevelObjectTerrain:
	var polygon_style: PolygonForm = object_data as PolygonForm
	if not polygon_style:
		return null
	
	var instance: LevelObjectTerrain = load("res://game/object_templates/polygon/level_object_terrain.tscn").instantiate()
	instance.polygon_data = polygon_style
	
	return instance


func _on_init() -> void:
	if not polygon_data and not source_object_id.is_empty():
		var game_object: GameObject = GameDB.get_object(source_object_id)
		if game_object:
			polygon_data = game_object.form as PolygonForm
	
	super._on_init()
	
	if polygon_data and static_body:
		body = static_body
		terrain_type = polygon_data.terrain_type
		static_body.set_meta(&"terrain", terrain_type)
	
	if not surface:
		return
	
	surface.data = polygon_data
	surface.base_style_name = base_style
	surface.topline_style_name = topline_style
	surface.decoration_style_name = decoration_set
	surface.collision_mode_name = collision_mode
	surface.decorations_enabled = decorations_enabled
	surface.rng_seed = rng_seed
	if not surface.rebuilt.is_connected(_sync_collision):
		surface.rebuilt.connect(_sync_collision)
	surface.set_topline_overrides(topline_overrides)
	surface.set_shape(outer_points, holes)


func _sync_collision() -> void:
	for shape: CollisionShape2D in _semisolid_shapes:
		if is_instance_valid(shape):
			shape.get_parent().remove_child(shape)
			shape.queue_free()
	_semisolid_shapes.clear()
	
	var mode: PolygonForm.CollisionMode = surface.get_collision_mode()
	var solid: bool = mode == PolygonForm.CollisionMode.SOLID
	
	if collision:
		collision.disabled = not solid
		collision.polygon = surface.get_ring() if solid else PackedVector2Array()
	
	if mode == PolygonForm.CollisionMode.SEMISOLID:
		_build_semisolid()


## Lays a one-way slab under every topline run. Each slab is rotated so its local -Y matches the
## edge's outward normal, which is the side Godot lets bodies land on, and extends inwards by the
## configured depth so a fast fall still has something to hit.
func _build_semisolid() -> void:
	if not static_body or not polygon_data:
		return
	
	var depth: float = polygon_data.collision_semisolid_depth
	var margin: float = polygon_data.collision_semisolid_margin
	
	for segment: PackedVector2Array in surface.get_topline_segments():
		for i: int in segment.size() - 1:
			var a: Vector2 = segment[i]
			var b: Vector2 = segment[i + 1]
			var length: float = a.distance_to(b)
			if length < 1.0:
				continue
			
			var shape: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
			shape.set_point_cloud(PackedVector2Array([
				Vector2(-length * 0.5, 0.0),
				Vector2(length * 0.5, 0.0),
				Vector2(length * 0.5, depth),
				Vector2(-length * 0.5, depth),
			]))
			
			var node: CollisionShape2D = CollisionShape2D.new()
			node.shape = shape
			node.position = (a + b) * 0.5
			node.rotation = (b - a).angle()
			node.one_way_collision = true
			node.one_way_collision_margin = margin
			static_body.add_child(node)
			_semisolid_shapes.append(node)
