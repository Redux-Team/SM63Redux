extends State

## The loose shell: slides until friction stops it, bounces off walls, and spins
## at the speed it is travelling. Walls are not allowed to block the floor here,
## so a shell sliding into a step keeps its footing instead of catching on it.


const SPIN_SPEED_DIVISOR: float = 60.0
## Below this the shell would take a very long time to coast to a stop, so it is
## simply stopped.
const STOP_THRESHOLD: float = 4.0
const FRICTION_KEY: StringName = &"shell"
const FRICTION_SCALE: float = 0.03


var _floor_block_backup: bool = true


func _enter() -> void:
	_floor_block_backup = entity.floor_block_on_wall
	entity.floor_block_on_wall = false
	var friction: FrictionComponent = entity.get_component(FrictionComponent) as FrictionComponent
	if friction:
		friction.modifiers.set_modifier(FRICTION_KEY, FRICTION_SCALE)


func _exit() -> void:
	entity.floor_block_on_wall = _floor_block_backup
	var friction: FrictionComponent = entity.get_component(FrictionComponent) as FrictionComponent
	if friction:
		friction.modifiers.clear_modifier(FRICTION_KEY)


func _tick(_delta: float) -> void:
	if entity.is_on_wall():
		entity.velocity.x *= -1.0
	
	if absf(entity.velocity.x) <= STOP_THRESHOLD:
		entity.velocity.x = 0.0
	
	if not is_zero_approx(entity.velocity.x):
		sprite.flip_h = entity.velocity.x < 0.0
	sprite.speed_scale = absf(entity.velocity.x) / SPIN_SPEED_DIVISOR
