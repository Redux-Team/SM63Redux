@tool
class_name GameObject
extends Resource

enum {
	LD_SELECTABLE,
	LD_DELETABLE,
	LD_LAYERABLE,
	LD_COPYABLE,
}

enum LDPlacementRules {
	BEHIND_ALL,
	BEHIND_PLAYER,
	FRONT_PLAYER,
	FRONT_ALL
}

enum ObjectCategory {
	ENTITY,
	ITEM,
	POLYGON,
	HAZARDS,
	PROPS,
	TRIGGER,
	ALL,
}

enum ObjectType {
	SPRITE,
	TELESCOPING,
	TEXTURED_PATH,
	CUSTOM,
}

enum AuthorityMode {
	SERVER,
	PEER,
}

enum CollisionAnchor {
	TOP,
	BOTTOM,
	LEFT,
	RIGHT,
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


@export_group("Overrides", "")
@export_subgroup("Entry")
@export var name_override: String
## Override this to group different objects together, if not overriden
## then the base ID is used.
@export var ld_index_id: String
## The list of properties that this object inherits.
## If disabled, the object will exist but will not be findable in the Object Browser.
@export var ld_indexable: bool = true
@export_subgroup("Editor")
@export var ld_select_tool_override: String
@export var ld_placement_tool_override: String
@export var ld_placement_rules: LDPlacementRules = LDPlacementRules.BEHIND_PLAYER
@export_flags("Selectable", "Deletable", "Layerable", "Copyable") var ld_flags: int = 15
## If disabled, this object cannot be captured into a group (e.g. the player spawn),
## so it never gets duplicated when groups are stamped or placed.
@export var ld_groupable: bool = true
## If enabled, the level designer guarantees only one instance of this object can
## exist in a level — placing another removes the previous one.
@export var ld_unique: bool = false
@export_subgroup("Instance")
@export var ld_editor_instance: PackedScene:
	set(ldi):
		ld_editor_instance = ldi
		notify_property_list_changed()
@export var game_instance: PackedScene:
	set(gi):
		game_instance = gi
		notify_property_list_changed()
@export_group("")
@export var ld_entry_texture: Texture2D:
	set(value):
		if value is AtlasTexture:
			ld_entry_texture = value
		else:
			ld_entry_texture = _make_entry_texture(value)
@export var ld_properties: Array[LDProperty]
@export var object_type: ObjectType = ObjectType.SPRITE:
	set(t):
		object_type = t
		notify_property_list_changed()

@export_category("Object Data")
@export var sprite_texture: Texture2D:
	set(value):
		sprite_texture = value
		if not ld_entry_texture:
			ld_entry_texture = value
@export var telescoping_atlas: Texture2D:
	set(value):
		if value is AtlasTexture:
			telescoping_atlas = value
		else:
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = value
			telescoping_atlas = atlas

@export_category("Editor Data")
@export_storage var ld_object_path: String:
	set(p):
		ld_object_path = p
		_update_subpath()
@export_subgroup("Editor Shape", "editor_shape")
## If not set, it will default to using the [member sprite_texture]'s rect.
@export var editor_shape_shape_override: Shape2D
@export var editor_shape_offset: Vector2

@export_category("Level Data")
## Press this button to open the level object scene, useful for doing certain
## things like copying a collision shape.
@export_group("Collision", "collision")
## If enabled and no shape is set, then it will use the [member sprite_texture]'s rect.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "collision") var collision_enabled: bool = false
@export var collision_shape: Shape2D
@export var collision_polygon: PackedVector2Array
@export var collision_offset: Vector2
@export var collision_expand: Vector2 = Vector2.ZERO
@export var collision_anchor: CollisionAnchor = CollisionAnchor.TOP
@export_subgroup("One Way", "collision_")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var collision_one_way: bool = true:
	set(value):
		collision_one_way = value
		notify_property_list_changed()
@export var collision_one_way_margin: float = 1.0
@export var collision_collapsed: bool = true


@export_group("Multiplayer", "game_")
@export var game_multiplayer_spawnable: bool = false
@export var game_authority_mode: AuthorityMode = AuthorityMode.SERVER

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



func _get_ignored_properties() -> PackedStringArray:
	return [
		"name_override", "ld_index_id", "ld_indexable", "ld_groupable", "ld_unique",
		"ld_select_tool_override", "ld_placement_tool_override", "ld_placement_rules", "ld_flags",
		"ld_properties", "ld_editor_instance", "game_instance", "ld_entry_texture",
		"object_type",
		"game_multiplayer_spawnable",
		"game_authority_mode",
	]


func _get_allowed_properties() -> PackedStringArray:
	match object_type:
		ObjectType.SPRITE:
			return [
				"sprite_texture", # Object
				"editor_shape_shape_override", "editor_offset", # Editor 
				"collision_enabled", "collision_one_way", "collision_shape", "collision_polygon", "collision_offset" # Level
			]
		ObjectType.TELESCOPING:
			return [
				"telescoping_atlas",
				"",
				"collision_enabled", "collision_anchor", "collision_expand", "collision_offset", "collision_one_way", "collision_one_way_margin"
			]
	return []


func _validate_property(property: Dictionary) -> void:
	if property.usage & (PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SUBGROUP):
		return
	
	if property.name in ["collision_one_way_margin", "collision_collapsed"]:
		if not collision_one_way:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		return
	
	if property.name in _get_allowed_properties() or property.name in _get_ignored_properties():
		return
	
	property.set("usage", PROPERTY_USAGE_NO_EDITOR)


func get_object_name() -> String:
	if name_override:
		return name_override
	return _snake_to_title(id)


func get_object_path() -> String:
	return ld_object_path


func get_editor_instance() -> LDObject:
	if ld_editor_instance:
		return ld_editor_instance.instantiate()
	
	match object_type:
		ObjectType.SPRITE: return LDObjectSprite.from_game_object(self)
		ObjectType.TELESCOPING: return LDObjectTelescoping.from_game_object(self)
	
	return LDObject.new()


func get_game_instance() -> Node:
	if game_instance:
		return game_instance.instantiate()
	
	match object_type:
		ObjectType.SPRITE: return LevelObjectSprite.from_game_object(self)
		ObjectType.TELESCOPING: return LevelObjectTelescoping.from_game_object(self)
	
	return null


func get_index_id() -> String:
	return ("%s:%s" % [ld_index_id, id]).to_lower()


static func get_category_name(cat_value: ObjectCategory) -> String:
	match cat_value:
		ObjectCategory.ENTITY: return "ENTITY"
		ObjectCategory.ITEM: return "ITEM"
		ObjectCategory.POLYGON: return "POLYGON"
		ObjectCategory.HAZARDS: return "HAZARDS"
		ObjectCategory.PROPS: return "PROPS"
		ObjectCategory.TRIGGER: return "TRIGGERS"
	return ""


static func get_category_value(cat_name: String) -> ObjectCategory:
	match cat_name.to_upper():
		"ENTITY": return ObjectCategory.ENTITY
		"ITEM": return ObjectCategory.ITEM
		"POLYGON": return ObjectCategory.POLYGON
		"HAZARDS": return ObjectCategory.HAZARDS
		"PROPS": return ObjectCategory.PROPS
		"TRIGGERS": return ObjectCategory.TRIGGER
	return ObjectCategory.ALL


func get_placement_tool() -> String:
	if not ld_placement_tool_override.is_empty():
		return ld_placement_tool_override
	
	match object_type:
		ObjectType.TELESCOPING: return "telescoping"
		ObjectType.TEXTURED_PATH: return "path"
	return ""


func get_select_tool() -> String:
	if not ld_select_tool_override.is_empty():
		return ld_select_tool_override
	
	match object_type:
		ObjectType.TELESCOPING: return "telescoping_edit"
		ObjectType.TEXTURED_PATH: return "path_edit"
	return ""



func has_property(key: StringName) -> bool:
	for prop: LDProperty in ld_properties:
		if prop.key == key:
			return true
	return false


func _update_subpath() -> void:
	if category_string:
		subpath = get_object_path().trim_prefix(category_string + "/")


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
