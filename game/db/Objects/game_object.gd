@tool
class_name GameObject
extends Resource

## One placeable thing: what it is ([member form]), what is bolted onto it ([member traits]), what a
## designer can tune on it, and how it appears in the object browser. Its category and group come
## from where the file lives, so dropping a .tres under game/db/Objects/<Category>/<Group>/ is all
## the registration there is.
##
## Almost nothing here is required. A decoration is a form holding a texture: the fields a designer
## edits are answered for by [method get_properties], which asks the form and the traits rather than
## making every object restate the same three lines.


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
## What the object is, and how both halves of it get built. Exactly one.
@export var form: ObjectForm
## Whatever is bolted on top of the form. As many as the object needs.
@export var traits: Array[ObjectTrait]

@export_group("Properties")
## Shared fields pulled in from [LDPropertyLibrary] by file name, on top of what the form gives.
@export var ld_shared_properties: PackedStringArray
## Fields this object alone has. Write them inline here rather than as files of their own, so they
## sit next to the object that reads them.
@export var ld_properties: Array[LDProperty]

@export_group("Entry")
## Defaults to the id in Title Case.
@export var name_override: String
## Defaults to whatever [member form] offers.
@export var ld_entry_texture: Texture2D:
	set(value):
		ld_entry_texture = value if value is AtlasTexture else _make_entry_texture(value)
## Groups several entries into one browser slot, so variants share a tile.
@export var ld_index_id: String
## Browser section this is filed under. Defaults to the folder the object lives in, which suits
## nearly everything; the nature decorations share one folder and are sorted by theme instead, so
## they say where they belong rather than having it read back out of their index id.
@export var ld_group_override: String
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


## Merged property list, built once. The database hands the same resource to every instance, so the
## merge is paid for by the first placement and no other.
var _properties: Array[LDProperty] = []
var _properties_built: bool = false

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


## Everything a designer can tune here: what the form offers, what each trait adds, the shared
## fields named on this object, and finally its own inline ones. Later entries replace earlier ones
## of the same key, so an object can narrow a field it was given rather than having to avoid it.
func get_properties() -> Array[LDProperty]:
	if _properties_built:
		return _properties
	
	_properties_built = true
	if form:
		_merge_properties(form.properties())
	for object_trait: ObjectTrait in traits:
		if object_trait:
			_merge_properties(object_trait.properties())
	_merge_properties(LDPropertyLibrary.get_properties(ld_shared_properties))
	_merge_properties(ld_properties)
	
	return _properties


func get_entry_texture() -> Texture2D:
	if ld_entry_texture:
		return ld_entry_texture
	return _make_entry_texture(form.get_entry_texture()) if form else null


func get_editor_instance() -> LDObject:
	var instance: LDObject = form.create_ld_object() if form else LDObject.new()
	if not instance:
		return null
	
	for object_trait: ObjectTrait in traits:
		if object_trait:
			object_trait.build_editor(instance)
	
	return instance


func get_game_instance() -> Node:
	var instance: Node = form.create_level_object() if form else null
	if not instance:
		return null
	
	for object_trait: ObjectTrait in traits:
		if object_trait:
			object_trait.build_game(instance)
	
	return instance


func get_placement_tool() -> String:
	if not ld_placement_tool_override.is_empty():
		return ld_placement_tool_override
	return form.get_placement_tool() if form else ""


func get_select_tool() -> String:
	if not ld_select_tool_override.is_empty():
		return ld_select_tool_override
	return form.get_select_tool() if form else ""


func get_index_id() -> String:
	return ("%s:%s" % [ld_index_id, id]).to_lower()


func has_property(key: StringName) -> bool:
	for prop: LDProperty in get_properties():
		if prop.key == key:
			return true
	return false


func _merge_properties(incoming: Array[LDProperty]) -> void:
	for prop: LDProperty in incoming:
		if not prop:
			continue
		
		var index: int = _index_of_property(prop.key)
		if index < 0:
			_properties.append(prop)
		else:
			_properties.set(index, prop)


func _index_of_property(key: StringName) -> int:
	for i: int in _properties.size():
		if _properties.get(i).key == key:
			return i
	return -1


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
