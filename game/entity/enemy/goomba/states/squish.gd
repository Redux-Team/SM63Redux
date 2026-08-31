extends GoombaState


const POP_DELAY: float = 0.2
const POP_VELOCITY: float = -280.0

@export var hit_box: HitBox

var _popped: bool = false


func _enter() -> void:
	_popped = false
	hit_box.set_deferred(&"monitoring", false)
	hit_box.set_deferred(&"monitorable", false)
	sprite.animation_finished.connect(goomba.queue_free, CONNECT_ONE_SHOT)


func _tick(_delta: float) -> void:
	if _popped or _is_ground_pounding():
		return
	
	if time < POP_DELAY:
		goomba.squished_by.velocity.y = 0.0
		return
	
	_popped = true
	goomba.squished_by.velocity.y = POP_VELOCITY


func _is_ground_pounding() -> bool:
	if not is_instance_valid(goomba.squished_by):
		return true
	return goomba.squished_by.machine.get_state_name().begins_with("GroundPound")
