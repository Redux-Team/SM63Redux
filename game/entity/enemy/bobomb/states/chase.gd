extends ChaseState


@export var fuse_time: float = 3.25
@export var fuse_light: PointLight2D
@export var modulate_speed_curve: Curve
@export var key: SmartSprite2D
@export var fuse: SmartSprite2D


func _enter() -> void:
	super()
	fuse_light.enabled = true
	fuse.play(&"fuse")
	key.speed_scale = effects.speed_scale if effects else 1.0


func _tick(delta: float) -> void:
	super(delta)
	sprite.self_modulate = _sample_modulate(time / fuse_time)


func _exit() -> void:
	sprite.self_modulate = Color.WHITE
	fuse_light.enabled = false


func _next() -> StringName:
	return &"Kaboom" if time >= fuse_time else &""


func _sample_modulate(progress: float) -> Color:
	var modulate_speed: float = 1.0 + modulate_speed_curve.sample(progress)
	var frequency: float = time * modulate_speed * modulate_speed
	return Color(1.0, 1.0 - sin(frequency), 1.0 - sin(frequency))
