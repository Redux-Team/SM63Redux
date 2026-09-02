@abstract
@tool
class_name ObjectTrait
extends Resource

## One additive piece of an object, on top of its exclusive [ObjectForm]. Traits are where
## composition lives: an object collects however many it needs, and each one contributes the fields
## a designer can tune plus whatever it has to build into the two halves of the object.
##
## Anything that would otherwise become a new form subclass, or a hand-written scene existing only
## to bolt one behaviour onto a sprite, belongs here instead.


## Fields this trait adds to whatever the form already offers. They are merged by key, so a trait
## can also restate one of the form's fields to narrow its range or rename its label.
func properties() -> Array[LDProperty]:
	return []


## Called on the freshly built level designer stand-in, before it is placed in the level.
func build_editor(_obj: LDObject) -> void:
	pass


## Called on the freshly built game object, before it is added to the tree or handed its property
## values, so anything added here is in place by the time properties are applied.
func build_game(_obj: Node) -> void:
	pass
