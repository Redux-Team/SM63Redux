class_name WingCap
extends CapMode

@export var state_redirects: Dictionary[String, StringName] = {}


func redirect_state(from: StringName, to: StringName) -> StringName:
	return state_redirects.get("%s>%s" % [from, to], to)


func allows_glide() -> bool:
	return true


func has_free_jump_chain() -> bool:
	return true


func dive_keeps_fall_speed() -> bool:
	return true
