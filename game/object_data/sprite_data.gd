@tool
class_name SpriteData
extends GameObjectData


@export var texture: Texture2D

@export_group("Editor Shape", "editor_shape")
## Hit-test shape in the level designer. Defaults to the texture's rect.
@export var editor_shape_override: Shape2D
@export var editor_shape_offset: Vector2

@export_group("Collision", "collision")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "collision") var collision_enabled: bool = false
## Falls back to the texture's rect when neither a shape nor a polygon is given.
@export var collision_shape: Shape2D
@export var collision_polygon: PackedVector2Array
@export var collision_offset: Vector2
@export var collision_one_way: bool = true
@export var collision_one_way_margin: float = 1.0


func get_entry_texture() -> Texture2D:
	return texture


func _build_ld_object() -> LDObject:
	return LDObjectSprite.from_data(self)


func _build_level_object() -> Node:
	return LevelObjectSprite.from_data(self)
