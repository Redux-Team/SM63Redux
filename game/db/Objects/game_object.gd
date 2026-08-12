@tool
class_name GameObject
extends Resource

## One placeable thing: what it is ([member data]), what a designer can tune on it
## ([member ld_properties]), and how it appears in the object browser. Its category and group come
## from where the file lives, so dropping a .tres under game/db/Objects/<Category>/<Group>/ is all
## the registration there is.


enum LDPlacementRules { BEHIND_ALL, BEHIND_PLAYER, FRONT_PLAYER, FRONT_ALL }
enum AuthorityMode { SERVER, PEER }

enum {
	LD_SELECTABLE,
	LD_DELETABLE,
	LD_LAYERABLE,
	LD_COPYABLE,
}

const OBJECTS_ROOT: String = "res://game/db/Objects/"


## Stable name a saved level refers to this object by. Defaults to the file name; set it explicitly
## only when you need the file to be renamable without orphaning already-placed instances.
@export var id: String
@export var data: GameObjectData
@export var ld_properties: Array[LDProperty]

@export_group("Entry")
## Defaults to the id in Title Case.
@export var name_override: String
## Defaults to whatever [member data] offers.
@export var ld_entry_texture: Texture2D:
	set(value):
		ld_entry_texture = value if value is AtlasTexture else _make_entry_texture(value)
## Groups several entries into one browser slot, so variants share a tile.
@export var ld_index_id: String
## When off, the object still loads and places but never shows up in the object browser.
@export var ld_indexable: bool = true

@export_group("Editor")
@export var ld_placement_rules: LDPlacementRules = LDPlacementRules.BEHIND_PLAYER
@export_flags("Selectable", "Deletable", "Layerable", "Copyable") var ld_flags: int = 15
## When off, this can't be captured into a stamp (e.g. the player spawn), so it never gets
## duplicated when stamps are stamped or placed.
@export var ld_stampable: bool = true
## When on, the level designer keeps exactly one instance per area - placing another removes the
## previous one.
@export var ld_unique: bool = false
@export var ld_select_tool_override: String
@export var ld_placement_tool_override: String

@export_group("Multiplayer", "game_")
@export var game_multiplayer_spawnable: bool = false
@export var game_authority_mode: AuthorityMode = AuthorityMode.SERVER


## Location under [constant OBJECTS_ROOT] without the extension, e.g. "Item/Collectible/yellow_coin".
var object_path: String:
	get:
		return resource_path.trim_prefix(OBJECTS_ROOT).trim_suffix(".tres")

## Top-level folder, e.g. "Item".
var category: String:
	get:
		return object_path.get_slice("/", 0)

## Second-level folder, e.g. "Collectible".
var group: String:
	get:
		return object_path.get_slice("/", 1) if object_path.get_slice_count("/") > 2 else ""

## Everything below the category, e.g. "Collectible/yellow_coin".
var subpath: String:
	get:
		return object_path.trim_prefix(category + "/")


func get_object_name() -> String:
	if name_override:
		return name_override
	return _snake_to_title(id)


func get_entry_texture() -> Texture2D:
	if ld_entry_texture:
		return ld_entry_texture
	return _make_entry_texture(data.get_entry_texture()) if data else null


func get_editor_instance() -> LDObject:
	return data.create_ld_object() if data else LDObject.new()


func get_game_instance() -> Node:
	return data.create_level_object() if data else null


func get_placement_tool() -> String:
	if not ld_placement_tool_override.is_empty():
		return ld_placement_tool_override
	return data.get_placement_tool() if data else ""


func get_select_tool() -> String:
	if not ld_select_tool_override.is_empty():
		return ld_select_tool_override
	return data.get_select_tool() if data else ""


func get_index_id() -> String:
	return ("%s:%s" % [ld_index_id, id]).to_lower()


func has_property(key: StringName) -> bool:
	for prop: LDProperty in ld_properties:
		if prop.key == key:
			return true
	return false


func _make_entry_texture(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null

	var size: Vector2i = tex.get_size()
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = tex

	var pos: Vector2i = Vector2i.ZERO

	if size.x >= 48 and size.y >= 48:
		pos = Vector2i((size.x - 48) >> 1, (size.y - 48) >> 1)
	else:
		pos = Vector2i(-((48 - size.x) >> 1), -((48 - size.y) >> 1))

	atlas.region = Rect2i(pos, Vector2i(48, 48))

	return atlas


func _snake_to_title(text: String) -> String:
	var words: PackedStringArray = text.split("_")
	for i: int in range(words.size()):
		words[i] = words[i].capitalize()
	return " ".join(words)
