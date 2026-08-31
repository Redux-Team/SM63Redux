extends State


const BOB_AMPLITUDE: float = 10.0
const BOB_SPEED: float = 2.0


func _tick(_delta: float) -> void:
	entity.velocity.y = BOB_AMPLITUDE * sin(time * BOB_SPEED)
