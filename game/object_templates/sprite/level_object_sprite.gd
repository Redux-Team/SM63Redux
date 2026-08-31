class_name LevelObjectSprite
extends LevelObject

@export var sprite: Sprite2D
@export var collision_shape: CollisionShape2D
@export var collision_polygon: CollisionPolygon2D


static func from_data(object_data: GameObjectData) -> LevelObjectSprite:
	var sprite_data: SpriteData = object_data as SpriteData
	if not sprite_data:
		return null

	var instance: LevelObjectSprite = load("uid://b2vmgflcudxmr").instantiate()

	instance.sprite.texture = sprite_data.texture

	# Collision
	instance.collision_shape.one_way_collision = sprite_data.collision_one_way
	instance.collision_shape.one_way_collision_margin = sprite_data.collision_one_way_margin
	instance.collision_shape.position = sprite_data.collision_offset
	instance.collision_polygon.position = sprite_data.collision_offset
	if sprite_data.collision_enabled:
		# If there is a collision shape, then override the sprite's collision shape
		if sprite_data.collision_shape:
			instance.collision_shape.shape = sprite_data.collision_shape
		# If points are set, then we use the polygon node instead
		elif not sprite_data.collision_polygon.is_empty():
			instance.collision_polygon.polygon = sprite_data.collision_polygon
			instance.collision_shape.queue_free()
		# If theres no collision shape set, default to the image texture's rect
		else:
			instance.collision_shape.shape = Packer.get_texture_as_shape(instance.sprite.texture)

		# We're not using the collision polygon, get rid of it.
		if not instance.collision_shape.is_queued_for_deletion():
			instance.collision_polygon.queue_free()

	return instance
