@tool
class_name AnimatedParticles
extends Node2D


enum Spread {
	RANDOM,
	EVEN,
	EXPLICIT,
}

@export var sprite_frames: SpriteFrames
@export var animation: StringName = &"default"
@export var amount: int = 8
@export var lifetime: float = 0.0
@export_group("Emission")
@export var emission_radius: float = 0.0
@export var spread_mode: Spread:
	set(m):
		spread_mode = m
		notify_property_list_changed()
@export_range(-360.0, 360.0, 0.1, "degrees") var direction: float = -90.0
@export_range(0.0, 180.0, 0.1, "degrees") var spread: float = 45.0
@export var angles: PackedFloat32Array = []
@export var speed_min: float = 0.0
@export var speed_max: float = 0.0
@export_group("Motion")
@export var gravity: Vector2 = Vector2.ZERO
@export var damping: float = 0.0
@export_group("Variation")
@export var scale_min: float = 1.0
@export var scale_max: float = 1.0
@export var speed_scale_min: float = 1.0
@export var speed_scale_max: float = 1.0
@export var random_start_frame: bool = false
@export var random_flip: bool = false


func burst(count: int = amount) -> void:
	if not sprite_frames or not sprite_frames.has_animation(animation):
		return
	
	for i: int in count:
		_spawn(i, count)


func get_angle_at(index: int, count: int) -> float:
	if spread_mode == Spread.EXPLICIT:
		if angles.is_empty():
			return direction
		return angles.get(index % angles.size())
	
	if spread_mode == Spread.EVEN and count > 1:
		var steps: int = count if spread >= 180.0 else count - 1
		return direction - spread + 2.0 * spread * index / steps
	
	if spread_mode == Spread.EVEN:
		return direction
	
	return direction + randf_range(-spread, spread)


func _spawn(index: int, count: int) -> void:
	var particle: Particle = Particle.new()
	particle.sprite_frames = sprite_frames
	particle.animation = animation
	particle.speed_scale = randf_range(speed_scale_min, speed_scale_max)
	particle.scale = Vector2.ONE * randf_range(scale_min, scale_max)
	particle.flip_h = random_flip and randf() < 0.5
	particle.velocity = Vector2.RIGHT.rotated(deg_to_rad(get_angle_at(index, count))) * randf_range(speed_min, speed_max)
	particle.gravity = gravity
	particle.damping = damping
	
	owner.add_sibling(particle)
	particle.z_index = z_index
	particle.global_position = global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf() * emission_radius
	particle.play()
	if random_start_frame:
		particle.frame = randi() % sprite_frames.get_frame_count(animation)
	
	var life: float = _particle_lifetime(particle.speed_scale)
	if life > 0.0:
		get_tree().create_timer(life).timeout.connect(particle.queue_free)
	else:
		particle.animation_finished.connect(particle.queue_free)


func _particle_lifetime(speed_scale: float) -> float:
	if lifetime > 0.0:
		return lifetime
	if not sprite_frames.get_animation_loop(animation):
		return 0.0
	
	var fps: float = sprite_frames.get_animation_speed(animation)
	if fps <= 0.0:
		return 0.0
	
	return sprite_frames.get_frame_count(animation) / (fps * maxf(speed_scale, 0.01))


func _validate_property(property: Dictionary) -> void:
	if property.name == &"angles" and spread_mode != Spread.EXPLICIT:
		property.set("usage", PROPERTY_USAGE_NO_EDITOR)
	elif property.name in [&"direction", &"spread"] and spread_mode == Spread.EXPLICIT:
		property.set("usage", PROPERTY_USAGE_NO_EDITOR)


class Particle extends AnimatedSprite2D:
	var velocity: Vector2
	var gravity: Vector2
	var damping: float
	
	
	func _physics_process(delta: float) -> void:
		velocity += gravity * delta
		if damping > 0.0:
			velocity = velocity.move_toward(Vector2.ZERO, damping * delta)
		
		position += velocity * delta
