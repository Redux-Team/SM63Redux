class_name RocketBoom
extends Node2D

@export var splash: AnimatedParticles
@export var down_trail: AnimatedParticles
@export var jet_trail: AnimatedParticles
@export var nozzle: Node2D
@export_group("Trails")
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var down_time: float = 0.2
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var jet_time: float = 0.35
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var trail_interval: float = 0.04
@export_group("Shake")
@export var shake_strength: float = 1.5
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var shake_duration: float = 0.15

var _down_left: float = 0.0
var _jet_left: float = 0.0
var _clock: float = 0.0


func _ready() -> void:
	top_level = true


func _physics_process(delta: float) -> void:
	_down_left = maxf(_down_left - delta, 0.0)
	_jet_left = maxf(_jet_left - delta, 0.0)
	if _down_left <= 0.0 and _jet_left <= 0.0:
		return
	
	_clock -= delta
	if _clock > 0.0:
		return
	
	_clock = trail_interval
	if _down_left > 0.0:
		down_trail.burst()
	if _jet_left > 0.0 and nozzle:
		jet_trail.global_position = nozzle.global_position
		jet_trail.direction = rad_to_deg(nozzle.global_transform.y.angle())
		jet_trail.burst()


func fire(at: Vector2) -> void:
	global_position = at
	_down_left = down_time
	_jet_left = jet_time
	_clock = 0.0
	var object: GameObject = GameObject.of(nozzle if nozzle else self)
	var parent: Node = object.get_parent() if object else Level.of(self)
	for particles: AnimatedParticles in [splash, down_trail, jet_trail]:
		particles.spawn_parent = parent
		particles.spawn_before = object
	
	splash.burst()
	var level: Level = Level.of(self)
	if level:
		level.camera.shake(shake_strength, shake_duration)
