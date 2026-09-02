@tool
class_name ObjectForm
extends Resource

## What an object *is*: the half of a [GameObject] that knows how to build it, in the level designer
## and in the game. A form is exclusive - an object is a sprite, or a path, or a polygon, never two -
## because each one is a different node edited with a different tool, so the combinations that would
## make no sense cannot be spelled. Anything additive belongs on [member GameObject.traits] instead.
##
## Each half can opt out of being built procedurally by naming a scene. The two are a ladder rather
## than a pair: most objects author neither, some author only the game half (an enemy the designer
## places as a plain sprite), and the hand-made ones author both.
##
## Scenes are stored as uids and loaded only when an object is actually built, so opening the object
## database does not pull in every scene in the game along with its textures and audio.


## Scenes are stored as uids and loaded only when an object is actually built.
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


## The fields every object built from this form gets, before its traits and its own additions. A
## decoration says nothing about properties precisely because this answers for it.
func properties() -> Array[LDProperty]:
	return LDPropertyLibrary.get_properties(PackedStringArray(["position"]))


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
