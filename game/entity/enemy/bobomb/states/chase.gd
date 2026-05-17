@tool
extends State

const CHASE_VELOCITY: float = 180.0

const FUSE_AMPLITUDE: float = 5.0
const FUSE_PERIOD: float = 0.02
const FUSE_OFFSET: float = 3

@export var fuse_light: PointLight2D
@export var modulate_speed_curve: Curve
@export var key: SmartSprite2D
@export var fuse: SmartSprite2D


func _on_enter() -> void:
	fuse_light.enabled = true
	fuse.play("fuse")
	key.speed_scale = sprite_speed_scale


func _on_physics_tick(_delta: float) -> void:
	sprite.flip_h = entity.velocity.x < 0
	
	#fuse_light.energy = FUSE_OFFSET + (FUSE_AMPLITUDE * get_osc())
	
	#sprite.self_modulate = Color(1.0, 1.0 - get_osc(modulate_speed_curve), 1.0 - get_osc(modulate_speed_curve))
	
	var t: float = get_elapsed_time() / runtime
	
	sprite.self_modulate = sample_modulate(t)
	
	
	entity.velocity.x += get_chase_vector() / 8
	entity.velocity.x = clampf(entity.velocity.x, -CHASE_VELOCITY, CHASE_VELOCITY)


func sample_modulate(t: float) -> Color:
	var modulate_speed: float = 1 + modulate_speed_curve.sample(t)
	var freq: float = get_elapsed_time() * modulate_speed * modulate_speed
	return Color(
		1.0,
		1.0 - sin(freq),
		1.0 - sin(freq),
	)


func get_chase_vector() -> float:
	return CHASE_VELOCITY * sign(entity.target.global_position.x - entity.global_position.x)


func _on_exit() -> void:
	sprite.self_modulate = Color.WHITE
	fuse_light.enabled = false
