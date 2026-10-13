extends PlayerState

@export var hitbox: HitBox
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var hitbox_time: float = 1.667
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var duration: float = 0.15
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var bounce_speed: float = 272.5
@export_group("Drag")
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s²") var drag: float = 500.0
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var min_speed: float = 45.0


func _enter() -> void:
	player.velocity.y = minf(player.velocity.y, 0.0)


func _tick(delta: float) -> void:
	if time >= hitbox_time and hitbox.monitorable:
		hitbox.disable()
	
	var speed: float = absf(player.velocity.x)
	if speed > min_speed:
		player.velocity.x = maxf(speed - drag * delta, min_speed) * signf(player.velocity.x)
	
	if time >= duration and time - delta < duration:
		player.velocity.y = -bounce_speed


func _exit() -> void:
	hitbox.enable()


func _next() -> StringName:
	if player.velocity.y < 0.0:
		return &"Fall"
	if player.is_on_floor():
		return &"Idle"
	return &"Fall" if time >= duration else &""


func get_gravity_scale() -> float:
	return 0.0 if time < duration else gravity_scale
