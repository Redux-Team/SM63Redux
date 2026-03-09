@tool
class_name GameObject
extends Resource

enum ObjectCategory {
	ALL,
	ENTITY,
	ITEM,
	TERRAIN,
	VOLUME,
	HARZARD,
	INTERACTABLE,
	TRIGGER,
}


@export var name: String:
	set(n):
		name = n.remove_char(47).strip_edges() # '/'
		category_path = get_category_path()
@export var subpath: String:
	set(sp):
		subpath = sp.strip_edges()
		category_path = get_category_path()


@export_group("LD Object")
@export var category_path: String


func get_category_path() -> String:
	return get_subpath() + name


func get_subpath() -> String:
	if subpath:
		return subpath if subpath.ends_with("/") else (subpath + "/")
	else:
		return ""
