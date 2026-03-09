@tool
class_name GameObject
extends Resource

enum ObjectCategory {
	ENTITY,
	ITEM,
	TERRAIN,
	VOLUME,
	HARZARD,
	INTERACTABLE,
	TRIGGER,
	UNKNOWN,
}


@export_storage var name: String:
	set(n):
		name = n.remove_char(47).strip_edges() # '/'
		ld_object_path = get_object_path()
@export_storage var category: ObjectCategory:
	set(c):
		category = c
		category_string = get_category_name(c).to_pascal_case()
@export_storage var category_string: String

@export_group("Editor", "ld_")
@export_storage var ld_object_path: String
@export var ld_preview_texture: Texture2D
@export_group("Game", "game_")
@export var game_instance: PackedScene


func get_object_path() -> String:
	return ld_object_path


static func get_category_name(cat_value: ObjectCategory) -> String:
	match cat_value:
		ObjectCategory.ENTITY: return "ENTITY"
		ObjectCategory.ITEM: return "ITEM"
		ObjectCategory.TERRAIN: return "TERRAIN"
		ObjectCategory.VOLUME: return "VOLUME"
		ObjectCategory.HARZARD: return "HARZARD"
		ObjectCategory.INTERACTABLE: return "INTERACTABLE"
		ObjectCategory.TRIGGER: return "TRIGGER"
	return ""


static func get_category_value(cat_name: String) -> ObjectCategory:
	match cat_name.to_upper():
		"ENTITY": return ObjectCategory.ENTITY
		"ITEM": return ObjectCategory.ITEM
		"TERRAIN": return ObjectCategory.TERRAIN
		"VOLUME": return ObjectCategory.VOLUME
		"HARZARD": return ObjectCategory.HARZARD
		"INTERACTABLE": return ObjectCategory.INTERACTABLE
		"TRIGGER": return ObjectCategory.TRIGGER
	return ObjectCategory.UNKNOWN
