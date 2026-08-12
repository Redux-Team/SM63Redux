@tool
class_name TelescopingData
extends GameObjectData


enum CollisionAnchor { TOP, BOTTOM, LEFT, RIGHT }


## Nine-patch source: the atlas region marks the stretchable middle, the margin around it the caps.
## A plain texture assigned here is wrapped into a full-size region automatically.
@export var atlas: Texture2D:
	set(value):
		atlas = value if value == null or value is AtlasTexture else _as_atlas(value)

## Hit-test shape in the level designer. Defaults to the collapsed nine-patch rect.
@export var editor_shape_override: Shape2D

@export_group("Collision", "collision")
@export var collision_anchor: CollisionAnchor = CollisionAnchor.TOP
@export var collision_expand: Vector2 = Vector2.ZERO
@export var collision_offset: Vector2
@export var collision_collapsed: bool = true
@export var collision_one_way: bool = true
@export var collision_one_way_margin: float = 1.0


func get_entry_texture() -> Texture2D:
	return atlas


func get_placement_tool() -> String:
	return "telescoping"


func get_select_tool() -> String:
	return "telescoping_edit"


func _build_ld_object() -> LDObject:
	return LDObjectTelescoping.from_data(self)


func _build_level_object() -> Node:
	return LevelObjectTelescoping.from_data(self)


func _as_atlas(texture: Texture2D) -> AtlasTexture:
	var wrapped: AtlasTexture = AtlasTexture.new()
	wrapped.atlas = texture
	return wrapped
