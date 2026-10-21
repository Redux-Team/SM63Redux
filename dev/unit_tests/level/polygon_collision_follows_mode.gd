static func run_test() -> void:
	var tree: SceneTree = Engine.get_main_loop()
	var outer: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(128, 0), Vector2(128, 64), Vector2(0, 64)])
	var data: ObjectData = ObjectData.create(&"terrain_grass")
	data.shape = {"outer": outer, "holes": [], "toplines": []}
	var terrain: GameObject = ObjectRegistry.spawn(data, GameObject.Context.GAME)
	tree.root.add_child(terrain)
	
	var collision: PolygonCollision = terrain.get_node(^"Game/Collision") as PolygonCollision
	var body: StaticBody2D = collision.body as StaticBody2D
	assert(collision.mode == PolygonCollision.CollisionMode.SOLID)
	assert(body.get_meta(&"terrain") == collision.terrain_type)
	assert(not collision.polygon.disabled)
	assert(collision.polygon.polygon == outer)
	assert(_slabs(body).is_empty())
	assert(terrain.is_solid())
	
	var shape: PolygonShape = terrain.shape as PolygonShape
	var hole: PackedVector2Array = PackedVector2Array([Vector2(32, 16), Vector2(96, 16), Vector2(96, 48), Vector2(32, 48)])
	shape.set_rings([outer, hole] as Array[PackedVector2Array], [] as Array[Dictionary])
	collision.sync()
	var polygons: Array[CollisionPolygon2D] = []
	for child: Node in body.get_children():
		if child is CollisionPolygon2D and not child.is_queued_for_deletion():
			polygons.append(child)
	assert(polygons.size() == shape.get_pieces().size())
	assert(polygons.size() >= 2)
	for polygon: CollisionPolygon2D in polygons:
		assert(not Geometry2D.is_point_in_polygon(Vector2(64, 32), polygon.polygon))
	
	shape.set_rings([outer] as Array[PackedVector2Array], [] as Array[Dictionary])
	collision.sync()
	assert(body.get_children().filter(func(child: Node) -> bool: return child is CollisionPolygon2D and not child.is_queued_for_deletion()).size() == 1)
	
	var edges: int = 0
	for segment: PackedVector2Array in shape.get_topline_segments():
		edges += segment.size() - 1
	assert(edges > 0)
	
	terrain.set_value(&"collision_mode", PolygonCollision.CollisionMode.SEMISOLID)
	collision.sync()
	assert(collision.polygon.disabled)
	assert(collision.polygon.polygon.is_empty())
	assert(_slabs(body).size() == edges)
	for slab: CollisionShape2D in _slabs(body):
		assert(slab.one_way_collision)
	
	terrain.set_value(&"collision_mode", PolygonCollision.CollisionMode.NONE)
	collision.sync()
	assert(collision.polygon.disabled)
	assert(collision.polygon.polygon.is_empty())
	assert(_slabs(body).is_empty())
	
	terrain.set_value(&"collision_mode", PolygonCollision.CollisionMode.SOLID)
	collision.sync()
	assert(not collision.polygon.disabled)
	assert(collision.polygon.polygon == outer)
	assert(_slabs(body).is_empty())
	terrain.free()


static func _slabs(body: Node) -> Array[CollisionShape2D]:
	var slabs: Array[CollisionShape2D] = []
	for child: Node in body.get_children():
		if child is CollisionShape2D and not child.is_queued_for_deletion():
			slabs.append(child)
	return slabs
