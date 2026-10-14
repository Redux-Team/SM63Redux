extends State

## The winged form: hovers in place, bobbing. Gravity is held off for as long as the wings are on
## rather than the form going without a gravity component, so losing them is a state change instead
## of a different scene.


const BOB_AMPLITUDE: float = 10.0
const BOB_SPEED: float = 2.0


func _enter() -> void:
	var gravity: GravityComponent = entity.get_component(GravityComponent) as GravityComponent
	if gravity:
		gravity.lock()


func _exit() -> void:
	var gravity: GravityComponent = entity.get_component(GravityComponent) as GravityComponent
	if gravity:
		gravity.unlock()


func _tick(_delta: float) -> void:
	entity.velocity.y = BOB_AMPLITUDE * sin(time * BOB_SPEED)
