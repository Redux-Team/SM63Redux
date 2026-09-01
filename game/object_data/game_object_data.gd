@tool
class_name GameObjectData
extends Resource

## What an object *is*: the half of a [GameObject] that knows how to build it, both in the level
## designer and in the game. Each kind of object is a subclass carrying only its own fields, so
## nothing has to declare properties it will never use.
##
## Setting a scene here overrides the procedural build for that half, which is how a hand-authored
## object opts out. An object that is nothing but a pair of scenes can use this base class directly.


## Scenes are stored as uids and loaded only when an object is actually built, so opening the
## object database does not pull in every scene in the game along with its textures and audio.
@export_storage var ld_scene_uid: String
@export_storage var game_scene_uid: String

## Editor-facing pickers for the two uids above. Shown but never serialised, so assigning one here
## does not put a hard reference back into the resource.
@export_custom(PROPERTY_HINT_RESOURCE_TYPE, "PackedScene", PROPERTY_USAGE_EDITOR) var ld_scene: PackedScene:
	get:
		return _load_scene(ld_scene_uid)
	set(scene):
		ld_scene_uid = _uid_of(scene)
@export_custom(PROPERTY_HINT_RESOURCE_TYPE, "PackedScene", PROPERTY_USAGE_EDITOR) var game_scene: PackedScene:
	get:
		return _load_scene(game_scene_uid)
	set(scene):
		game_scene_uid = _uid_of(scene)


## Held once loaded so repeated level loads do not re-read the scene off disk; the database keeps
## this resource alive, the scene files are only pulled in for objects that actually get built.
var _ld_scene: PackedScene
var _game_scene: PackedScene


func create_ld_object() -> LDObject:
	if not _ld_scene:
		_ld_scene = _load_scene(ld_scene_uid)
	if _ld_scene:
		return _ld_scene.instantiate()
	return _build_ld_object()


func create_level_object() -> Node:
	if not _game_scene:
		_game_scene = _load_scene(game_scene_uid)
	if _game_scene:
		return _game_scene.instantiate()
	return _build_level_object()


func _load_scene(uid: String) -> PackedScene:
	if uid.is_empty() or not ResourceLoader.exists(uid):
		return null
	
	return load(uid) as PackedScene


func _uid_of(scene: PackedScene) -> String:
	if not scene or scene.resource_path.is_empty():
		return ""
	
	return ResourceUID.id_to_text(ResourceLoader.get_resource_uid(scene.resource_path))


## Texture the object browser falls back to when the [GameObject] has no explicit entry texture.
func get_entry_texture() -> Texture2D:
	return null


func get_placement_tool() -> String:
	return ""


func get_select_tool() -> String:
	return ""


func _build_ld_object() -> LDObject:
	return LDObject.new()


func _build_level_object() -> Node:
	return null
