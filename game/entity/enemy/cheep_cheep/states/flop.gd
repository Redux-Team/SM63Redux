extends CheepCheepState


const FLOP_SPEED_MIN: int = 130
const FLOP_SPEED_MAX: int = 180
const FLOP_DRIFT: int = 30


func _tick(_delta: float) -> void:
	if cheep_cheep.is_on_floor():
		cheep_cheep.velocity.y = -randi_range(FLOP_SPEED_MIN, FLOP_SPEED_MAX)
		cheep_cheep.velocity.x = randi_range(-FLOP_DRIFT, FLOP_DRIFT)
