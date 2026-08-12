@tool
class_name GameObjectData
extends Resource

## What an object *is*: the half of a [GameObject] that knows how to build it, both in the level
## designer and in the game. Each kind of object is a subclass carrying only its own fields, so
## nothing has to declare properties it will never use.
##
## Setting a scene here overrides the procedural build for that half, which is how a hand-authored
## object opts out. An object that is nothing but a pair of scenes can use this base class directly.


@export var ld_scene: PackedScene
@export var game_scene: PackedScene


func create_ld_object() -> LDObject:
	if ld_scene:
		return ld_scene.instantiate()
	return _build_ld_object()


func create_level_object() -> Node:
	if game_scene:
		return game_scene.instantiate()
	return _build_level_object()


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
