#@tool
#class_name SpriteData
#extends ObjectData
#
#const LD_TEMPLATE = preload("uid://bfyhrduit8tqm")
#const LEVEL_TEMPLATE = preload("uid://b2vmgflcudxmr")
#
#@export var sprite_texture: Texture2D
#
#@export_group("Level")
### Press this button to open the level object scene, useful for doing certain
### things like copying a collision shape.
#
#@export_subgroup("Collision", "collision")
### If enabled and no shape is set, then it will use the [member sprite_texture]'s rect.
#@export_custom(PROPERTY_HINT_GROUP_ENABLE, "collision") var collision_enabled: bool = false
#@export var collision_shape: Shape2D
#@export var collision_polygon: PackedVector2Array
#@export var collision_offset: Vector2
#
#
#@export_group("Editor")
#@export_subgroup("Editor Shape", "editor_shape")
### If not set, it will default to using the [member sprite_texture]'s rect.
#@export var editor_shape_shape_override: Shape2D
#@export var editor_shape_offset: Vector2
#
#
#func setup_ld_object() -> LDObject:
	#var ld_object_sprite: LDObjectSprite = LD_TEMPLATE.instantiate() as LDObjectSprite
	#
	## Sprite
	#ld_object_sprite.sprite_ref.texture = sprite_texture
	#
	## EditorShape
	#if editor_shape_shape_override:
		#ld_object_sprite.editor_placement_rect.shape = editor_shape_shape_override
	#else:
		#ld_object_sprite.editor_placement_rect.shape = _get_sprite_as_shape()
	#
	#return ld_object_sprite
#
#
#func setup_level_object() -> Node:
	#var level_object_sprite: LevelObjectSprite = LEVEL_TEMPLATE.instantiate() as LevelObjectSprite
	#
	#level_object_sprite.sprite.texture = sprite_texture
	#
	## Collision
	#if collision_enabled:
		## If there is a collision shape, then override the sprite's collision shape
		#if collision_shape:
			#level_object_sprite.collision_shape.shape = collision_shape
		## If points are set, then we use the polygon node instead
		#elif collision_polygon:
			#level_object_sprite.collision_polygon.polygon = collision_polygon
			#level_object_sprite.collision_shape.queue_free()
		## If theres no collision shape set, default to the image texture's rect
		#else:
			##level_object_sprite.collision_shape.shape = Packer.get
		#
		## We're not using the collision polygon, get rid of it.
		#if not level_object_sprite.collision_shape.is_queued_for_deletion():
			#level_object_sprite.collision_polygon.queue_free()
	#
	#return level_object_sprite
