@tool
class_name SpriteForm
extends ObjectForm

## A plain sprite, which is what nearly every decoration is. A texture is the whole definition: the
## designer gets position, rotation and scale without the object listing them.


@export var texture: Texture2D

@export_group("Transform")
## Turn off for anything the game would not know how to draw turned or resized - most entities and
## items, whose scenes assume they sit upright at their authored size.
@export var allow_rotation: bool = true
@export var allow_scale: bool = true

@export_group("Editor Shape", "editor_shape")
## Hit-test shape in the level designer. Defaults to the texture's rect.
@export var editor_shape_override: Shape2D
@export var editor_shape_offset: Vector2


func properties() -> Array[LDProperty]:
	var keys: PackedStringArray = PackedStringArray(["position"])
	if allow_rotation:
		keys.append("rotation")
	if allow_scale:
		keys.append("scale")
	
	return LDPropertyLibrary.get_properties(keys)


func get_entry_texture() -> Texture2D:
	return texture


func _build_ld_object() -> LDObject:
	return LDObjectSprite.from_data(self)


func _build_level_object() -> Node:
	return LevelObjectSprite.from_data(self)
