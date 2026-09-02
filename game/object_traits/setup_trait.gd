@tool
class_name SetupTrait
extends ObjectTrait

## Values written onto the object this entry builds, in the game and in the level designer both.
## It is what lets several entries share one scene and differ only in how it wakes up: the koopa,
## the parakoopa and the loose shell are one object with three entries, each naming the form it
## starts in.
##
## Keys are property names on the built node. A key the object does not have is left alone, so an
## entry can say something only one of the two halves reads.


@export var values: Dictionary[StringName, Variant]


func build_editor(obj: LDObject) -> void:
	_apply(obj)


func build_game(obj: Node) -> void:
	_apply(obj)


func _apply(obj: Node) -> void:
	for key: StringName in values:
		obj.set(key, values.get(key))
