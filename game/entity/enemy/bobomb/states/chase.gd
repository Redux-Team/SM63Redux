extends BobombState


const CHASE_VELOCITY: float = 180.0

const FUSE_AMPLITUDE: float = 5.0
const FUSE_PERIOD: float = 0.02
const FUSE_OFFSET: float = 3

@export var fuse_time: float = 3.25
@export var fuse_light: PointLight2D
@export var modulate_speed_curve: Curve
@export var key: SmartSprite2D
@export var fuse: SmartSprite2D


func _enter() -> void:
	fuse_light.enabled = true
	fuse.play(&"fuse")
	key.speed_scale = effects.speed_scale if effects else 1.0


func _tick(_delta: float) -> void:
	sprite.flip_h = bobomb.velocity.x < 0.0
	
	#fuse_light.energy = FUSE_OFFSET + (FUSE_AMPLITUDE * get_osc())
	
	#sprite.self_modulate = Color(1.0, 1.0 - get_osc(modulate_speed_curve), 1.0 - get_osc(modulate_speed_curve))
	
	sprite.self_modulate = sample_modulate(time / fuse_time)
	
	bobomb.velocity.x = clampf(bobomb.velocity.x + get_chase_vector() / 8.0, -CHASE_VELOCITY, CHASE_VELOCITY)


func _exit() -> void:
	sprite.self_modulate = Color.WHITE
	fuse_light.enabled = false


func _next() -> StringName:
	return &"Kaboom" if time >= fuse_time else &""


func sample_modulate(t: float) -> Color:
	var modulate_speed: float = 1 + modulate_speed_curve.sample(t)
	var freq: float = time * modulate_speed * modulate_speed
	return Color(
		1.0,
		1.0 - sin(freq),
		1.0 - sin(freq),
	)


func get_chase_vector() -> float:
	if not is_instance_valid(bobomb.target):
		return 0.0
	return CHASE_VELOCITY * signf(bobomb.target.global_position.x - bobomb.global_position.x)
