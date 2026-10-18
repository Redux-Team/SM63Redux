class_name InvisibleCap
extends CapMode

@export_flags_2d_physics var passable_layers: int = 0

var _removed_layers: int = 0


func _enter() -> void:
	super()
	_removed_layers = player.collision_mask & passable_layers
	player.collision_mask &= ~passable_layers


func _exit() -> void:
	super()
	player.collision_mask |= _removed_layers


func is_undetectable() -> bool:
	return true


func is_intangible() -> bool:
	return true


func is_harmless() -> bool:
	return true
