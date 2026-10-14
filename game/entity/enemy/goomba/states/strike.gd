extends GoombaState


const GROUND_DELAY: float = 0.1
const WATER_TIMEOUT: float = 1.0

@export var hit_box: HitBox

var _finishing: bool = false


func _enter() -> void:
	_finishing = false
	sprite.play(&"strike")
	hit_box.set_deferred(&"monitorable", false)
	hit_box.set_deferred(&"monitoring", false)


func _tick(_delta: float) -> void:
	if _finishing or time <= GROUND_DELAY:
		return
	
	if not goomba.is_in_water():
		if goomba.is_on_floor():
			_pop()
		return
	
	if time > WATER_TIMEOUT:
		goomba.queue_free()
	elif goomba.is_on_anything():
		_pop()


func _pop() -> void:
	_finishing = true
	sprite.play(&"squish")
	sprite.animation_finished.connect(goomba.queue_free, CONNECT_ONE_SHOT)
