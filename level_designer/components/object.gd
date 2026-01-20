@tool
class_name GameObject
extends Resource

enum ObjectType {
	PLAYER, # All player related objects (Player, PlayerSpawner, FLUDD Box, etc.)
	ENEMY, # Enemies (Goomba, Koopa, Cheep-cheep etc.)
	NPC, # NPCs (mainly just Toads)
	ITEM, # Powerups & collectables: 
	INTERACTABLE, # Interactable (special) objects: 
	TERRAIN, # self explanatory
	FLUID, # Water, Lava, Poison, etc idk
	CUSTOM # anything else
}


@export var name: String:
	set(n):
		name = n.remove_char(47).strip_edges() # '/'
		category_path = get_category_path()
@export var type: ObjectType = ObjectType.CUSTOM:
	set(t):
		type = t
		category_path = get_category_path()
@export var subpath: String:
	set(sp):
		subpath = sp.strip_edges()
		category_path = get_category_path()


@export_group("LD Object")
@export var category_path: String


func get_category_path() -> String:
	match type:
		ObjectType.PLAYER: return "Player/" + get_subpath() + name
		ObjectType.ENEMY: return "Entities/Enemy/" + get_subpath() + name
		ObjectType.NPC: return "Entities/NPC/" + get_subpath() + name
		ObjectType.INTERACTABLE: return "Entities/Interactable/" + get_subpath() + name
		ObjectType.ITEM: return "Entities/Item/" + get_subpath() + name
		ObjectType.TERRAIN: return "Terrain/" + get_subpath() + name
		ObjectType.FLUID: return "Fluids/" + get_subpath() + name
	return ""


func get_subpath() -> String:
	if subpath:
		return subpath if subpath.ends_with("/") else (subpath + "/")
	else:
		return ""
