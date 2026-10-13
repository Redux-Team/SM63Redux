extends PlayerState

## Feet hitbox that squishes what the player lands on.
@export var hitbox: HitBox
## Time the feet hitbox stays live after the stomp starts.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var hitbox_time: float = 1.667
## Time gravity is suspended before bouncing.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var duration: float = 0.15
## Upward speed set once the stomp ends.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var bounce_speed: float = 272.5
@export_group("Drag")
## Horizontal deceleration while stomping.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s²") var drag: float = 500.0
## Horizontal speed the stomp drag stops at.
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
