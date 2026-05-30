class_name LevelObjectSprite
extends LevelObject

@export var sprite: Sprite2D
@export var collision_shape: CollisionShape2D
@export var collision_polygon: CollisionPolygon2D


static func from_game_object(game_object: GameObject = null) -> LevelObjectSprite:
	if not game_object:
		return null
	
	var instance: LevelObjectSprite = preload("uid://b2vmgflcudxmr").instantiate()
	
	instance.sprite.texture = game_object.sprite_texture
	
	# Collision
	instance.collision_shape.one_way_collision = game_object.collision_one_way
	instance.collision_shape.one_way_collision_margin = game_object.collision_one_way_margin
	if game_object.collision_enabled:
		# If there is a collision shape, then override the sprite's collision shape
		if game_object.collision_shape:
			instance.collision_shape.shape = game_object.collision_shape
		# If points are set, then we use the polygon node instead
		elif game_object.collision_polygon:
			instance.collision_polygon.polygon = game_object.collision_polygon
			instance.collision_shape.queue_free()
		# If theres no collision shape set, default to the image texture's rect
		else:
			instance.collision_shape.shape = Packer.get_texture_as_shape(instance.sprite.texture)
		
		# We're not using the collision polygon, get rid of it.
		if not instance.collision_shape.is_queued_for_deletion():
			instance.collision_polygon.queue_free()
	
	return instance
