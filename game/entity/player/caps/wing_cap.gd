class_name WingCap
extends CapMode

@export var state_redirects: Dictionary[String, StringName] = {}
@export var wings: Array[SmartSprite2D] = []
@export var idle_animation: StringName = &"idle"
@export var flap_animation: StringName = &"flap"


func redirect_state(from: StringName, to: StringName) -> StringName:
	return state_redirects.get("%s>%s" % [from, to], to)


func _show_look(shown: bool) -> void:
	super(shown)
	for wing: SmartSprite2D in wings:
		wing.follow_shown = shown


func set_flapping(flapping: bool) -> void:
	for wing: SmartSprite2D in wings:
		wing.follow_default = flap_animation if flapping else idle_animation


func _exit() -> void:
	super()
	set_flapping(false)


func allows_glide() -> bool:
	return true


func has_free_jump_chain() -> bool:
	return true


func dive_keeps_fall_speed() -> bool:
	return true
