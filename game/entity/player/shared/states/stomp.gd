extends PlayerState


@export var feet_hitbox: HitBox

var _hitbox_closed: bool = false


func _enter() -> void:
	_hitbox_closed = false
	player.begin_stomp()


func _tick(delta: float) -> void:
	if not _hitbox_closed and frames > player.stomp_hitbox_frames:
		_hitbox_closed = true
		feet_hitbox.disable()
	
	player.tick_stomp(delta)
	
	var speed: float = absf(player.velocity.x)
	if speed <= player.stomp_min_speed:
		return
	
	player.velocity.x = maxf(speed - player.stomp_drag * delta, player.stomp_min_speed) * signf(player.velocity.x)


func _exit() -> void:
	feet_hitbox.enable()
	player.cancel_stomp()


func _next() -> StringName:
	if player.velocity.y < 0.0:
		return &"Fall"
	if player.is_on_floor():
		return &"Idle"
	return &"Fall" if player.stomp_timer <= 0.0 else &""
