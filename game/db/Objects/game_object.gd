@tool
class_name GameObject
extends Resource

enum {
	LD_MOVABLE,
	LD_SELECTABLE,
	LD_DELETABLE
}


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


# These are cached to not have to do string manipulation every time we index a bunch of these resources.
@export_storage var id: String
@export_storage var category: ObjectCategory:
	set(c):
		category = c
		category_string = get_category_name(c).to_pascal_case()
		_update_subpath()
@export_storage var category_string: String
@export_storage var subpath: String:
	set(s):
		subpath = s
		group_path = s.trim_suffix("/" + s.get_file())
@export_storage var group_path: String

@export var name_override: String

@export_group("Editor", "ld_")
@export_storage var ld_object_path: String:
	set(p):
		ld_object_path = p
		_update_subpath()
@export var ld_entry_texture: Texture2D:
	set(value):
		if value is AtlasTexture:
			ld_entry_texture = value
		else:
			ld_entry_texture = _make_atlas_texture(value)
@export var ld_editor_instance: PackedScene
@export var ld_properties: Array[LDProperty]
@export var ld_indexable: bool = true
@export_subgroup("Flags")
@export_flags("Movable", "Selectable", "Deletable") var ld_flags: int = 7

@export_group("Game", "game_")
@export var game_instance: PackedScene

@warning_ignore("unused_private_class_variable")
@export_tool_button("Update Internal Info") var _update_internal_info: Callable:
	get:
		return func() -> void:
			_update_subpath()

@warning_ignore("unused_private_class_variable")
@export_tool_button("Print Internal Info") var _print_internal_info: Callable:
	get:
		return func() -> void:
			print(
				"get_object_name() -> ", get_object_name(), "\n",
				"get_object_path() -> ", get_object_path(), "\n",
				"get_category_name(category) -> ", get_category_name(category), "\n",
				"id -> ", id, "\n",
				"category -> ", category, "\n",
				"category_string -> ", category_string, "\n",
				"subpath -> ", subpath, "\n",
				"group_path -> ", group_path, "\n",
				"ld_object_path -> ", ld_object_path, "\n",
			)


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


func has_property(key: StringName) -> bool:
	for prop: LDProperty in ld_properties:
		if prop.key == key:
			return true
	return false


func _update_subpath() -> void:
	if category_string:
		subpath = get_object_path().trim_prefix(category_string + "/")


func _make_atlas_texture(tex: Texture2D) -> Texture2D:
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
