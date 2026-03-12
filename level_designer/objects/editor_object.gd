@tool
class_name EditorObject
extends Node2D

enum PlacementRules {
	PLACE,
	EXPAND_CENTER_X,
	EXPAND_EDGES_X,
}

@export var placement_rules: PlacementRules = PlacementRules.PLACE
@export var is_preview: bool = true


## Override to define placement behavior. Return true when placement is confirmed.
func _placement_rules() -> bool:
	return true


func _place() -> void:
	is_preview = false


## Override to define hover behavior.
func _hover_rules() -> void:
	pass
