@tool
class_name GameObject
extends Resource

enum {
	LD_SELECTABLE,
	LD_DELETABLE
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
	CUSTOM,
}

enum AuthorityMode {
	SERVER,
	PEER,
}

const TEMPLATES: Dictionary = {
	LD = {
		SPRITE = "uid://bfyhrduit8tqm",
	},
	LEVEL = {
		SPRITE = "uid://b2vmgflcudxmr",
	}
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
@export_flags("Selectable", "Deletable") var ld_flags: int = 3
@export_subgroup("Instance")
@export var ld_properties: Array[LDProperty]
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
			ld_entry_texture = _make_atlas_texture(value)
@export var object_data: ObjectData
@export var object_type: ObjectType = ObjectType.SPRITE:
	set(t):
		object_type = t
		notify_property_list_changed()
@export var sprite_texture: Texture2D:
	set(value):
		sprite_texture = value
		if not ld_entry_texture:
			ld_entry_texture = value


@export_category("Editor")
@export_storage var ld_object_path: String:
	set(p):
		ld_object_path = p
		_update_subpath()
@export_subgroup("Editor Shape", "editor_shape")
## If not set, it will default to using the [member sprite_texture]'s rect.
@export var editor_shape_shape_override: Shape2D
@export var editor_shape_offset: Vector2

@export_category("Level ")
## Press this button to open the level object scene, useful for doing certain
## things like copying a collision shape.
@export_group("Collision", "collision")
## If enabled and no shape is set, then it will use the [member sprite_texture]'s rect.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "collision") var collision_enabled: bool = false
@export var collision_shape: Shape2D
@export var collision_polygon: PackedVector2Array
@export var collision_offset: Vector2


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


func migrate_from_object_data() -> bool:
	if not object_data:
		return false
	
	if object_data is SpriteData:
		var data: SpriteData = object_data as SpriteData
		sprite_texture = data.sprite_texture
		collision_enabled = data.collision_enabled
		collision_shape = data.collision_shape
		collision_polygon = data.collision_polygon
		collision_offset = data.collision_offset
		editor_shape_shape_override = data.editor_shape_shape_override
		editor_shape_offset = data.editor_shape_offset
		object_type = ObjectType.SPRITE
		object_data = null
		notify_property_list_changed()
		return true
	
	return false


func _validate_property(property: Dictionary) -> void:
	if _get_type_properties(ObjectType.SPRITE).has(property.get("name", "")):
		if object_type != ObjectType.SPRITE:
			property.usage = PROPERTY_USAGE_NO_EDITOR


func _get_type_properties(type: ObjectType) -> PackedStringArray:
	match type:
		ObjectType.SPRITE:
			return PackedStringArray(["collision_enabled", "collision_shape", "collision_polygon", "collision_offset", "editor_shape_shape_override", "editor_shape_offset"])
		_:
			return PackedStringArray()


func get_object_name() -> String:
	if name_override:
		return name_override
	return _snake_to_title(id)


func get_object_path() -> String:
	return ld_object_path


func get_editor_instance() -> LDObject:
	if object_data:
		return object_data.setup_ld_object()
	
	if ld_editor_instance:
		return ld_editor_instance.instantiate()
	
	return null


func get_game_instance() -> Node:
	if object_data:
		return object_data.setup_level_object()
	
	if game_instance:
		return game_instance.instantiate()
	
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
