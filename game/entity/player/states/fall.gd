extends PlayerState

## Downward speed that must be reached before a spin can start.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var spin_min_speed: float = 100.0
@export_group("Wing Flap")
@export var flap_gravity_scale: float = 0.35
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var flap_fall_speed: float = 90.0
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var flap_halflife: float = 0.08

var _flapping: bool = false


func _enter() -> void:
	var previous: State = machine.get_last_state()
	if not previous:
		return
	
	if previous.name in [&"DoubleJump", &"TripleJump"]:
		sprite.play(&"double_jump_fall")
	elif previous.name == &"Spin" or not _is_airborne(previous):
		sprite.play(&"fall_loop")


func _tick(delta: float) -> void:
	_set_flapping(player.can_glide() and controls.is_held(&"jump") and player.velocity.y > 0.0)
	if _flapping and player.velocity.y > flap_fall_speed:
		player.velocity.y = Motion.damp(player.velocity.y, flap_fall_speed, flap_halflife, delta)


func _exit() -> void:
	_set_flapping(false)


func get_gravity_scale() -> float:
	return gravity_scale * flap_gravity_scale if _flapping else gravity_scale


func _next() -> StringName:
	if player.has_landed():
		return &"Idle"
	if controls.is_held(&"spin") and player.velocity.y > spin_min_speed:
		return &"Spin"
	if player.can_dive and controls.is_just_pressed(&"dive"):
		return &"Dive"
	return &""


func _set_flapping(flapping: bool) -> void:
	if flapping == _flapping:
		return
	
	_flapping = flapping
	player.set_wings_flapping(flapping)


func _is_airborne(state: State) -> bool:
	var node: Node = state
	while node is State:
		if node.name == &"Airborne":
			return true
		node = node.get_parent()
	
	return false
