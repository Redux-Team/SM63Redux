extends PlayerState

## Hitbox active for the whole ground pound.
@export var hitbox: HitBox

var _armed: bool = false


func _enter() -> void:
	_armed = false
	_sync_hitbox()


func _tick(_delta: float) -> void:
	_sync_hitbox()


func _exit() -> void:
	_armed = false
	hitbox.disable()


func _next() -> StringName:
	return &"GroundPoundStart" if is_current() else &""


func _sync_hitbox() -> void:
	var armed: bool = not player.is_swimming()
	if armed == _armed:
		return
	
	_armed = armed
	if armed:
		hitbox.enable()
	else:
		hitbox.disable()
