@tool
class_name PathForm
extends ObjectForm


@export var line_texture: Texture2D
@export var head_texture: Texture2D
## Splits long runs so the line texture tiles instead of stretching.
@export var subdivide: bool = true

@export_group("Collision", "collision")
@export var collision_stem: bool = false
@export var collision_stem_width: float = 16.0
@export var collision_head: bool = false
@export var collision_head_polygon: PackedVector2Array


func properties() -> Array[LDProperty]:
	return LDPropertyLibrary.get_properties(PackedStringArray(["position", "path_points"]))


func get_entry_texture() -> Texture2D:
	return head_texture


func get_placement_tool() -> String:
	return "path"


func get_select_tool() -> String:
	return "path_edit"


func _build_ld_object() -> LDObject:
	return LDObjectPath.from_data(self)


func _build_level_object() -> Node:
	return LevelObjectPath.from_data(self)
