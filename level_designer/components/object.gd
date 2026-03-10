@tool
class_name GameObject
extends Resource

enum ObjectCategory {
	ENTITY,
	ITEM,
	TERRAIN,
	VOLUME,
	HAZARDS,
	PROPS,
	TRIGGER,
	ALL,
}


@export_storage var id: String
@export var name_override: String
@export_storage var category: ObjectCategory:
	set(c):
		category = c
		category_string = get_category_name(c).to_pascal_case()
		_update_subpath()

# These are cached to not have to do string manipulation every time we index a bunch of these resources.
@export_storage var category_string: String
@export_storage var subpath: String:
	set(s):
		subpath = s
		group_path = s.trim_suffix("/" + s.get_file())
@export_storage var group_path: String

@export_group("Editor", "ld_")
@export_storage var ld_object_path: String
@export var ld_preview_texture: Texture2D
@export var ld_indexable: bool = true
@export_group("Game", "game_")
@export var game_instance: PackedScene


func get_object_name() -> String:
	if name_override:
		return name_override
	
	return _snake_to_title(id)


func get_object_path() -> String:
	return ld_object_path


static func get_category_name(cat_value: ObjectCategory) -> String:
	match cat_value:
		ObjectCategory.ENTITY: return "ENTITY"
		ObjectCategory.ITEM: return "ITEM"
		ObjectCategory.TERRAIN: return "TERRAIN"
		ObjectCategory.VOLUME: return "VOLUMES"
		ObjectCategory.HAZARDS: return "HAZARDS"
		ObjectCategory.PROPS: return "PROPS"
		ObjectCategory.TRIGGER: return "TRIGGERS"
	return ""


static func get_category_value(cat_name: String) -> ObjectCategory:
	match cat_name.to_upper():
		"ENTITY": return ObjectCategory.ENTITY
		"ITEM": return ObjectCategory.ITEM
		"TERRAIN": return ObjectCategory.TERRAIN
		"VOLUMES": return ObjectCategory.VOLUME
		"HAZARDS": return ObjectCategory.HAZARDS
		"PROPS": return ObjectCategory.PROPS
		"TRIGGERS": return ObjectCategory.TRIGGER
	return ObjectCategory.ALL


func _update_subpath() -> void:
	if category_string:
		subpath = get_object_path().trim_prefix(category_string + "/")


func _snake_to_title(text: String) -> String:
	var words: PackedStringArray = text.split("_")

	for i in range(words.size()):
		words[i] = words[i].capitalize()

	return " ".join(words)
