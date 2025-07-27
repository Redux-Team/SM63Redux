class_name ParticleEmitter
extends CPUParticles2D

@export var high_particle_amount: int
@export var medium_particle_amount: int
@export var low_particle_amount: int

var _preprocess: float = 0.0
var _particle_amount: String


func _ready() -> void:
	_preprocess = preprocess
	_particle_amount = Config.display.particle_amount
	Singleton.config_changed.connect(_on_config_changed)
	
	update_particles()


func update_particles() -> void:
	if Config.display.particle_amount == "None":
		_particle_amount = "None"
		preprocess = 0
		restart()
		emitting = false
		return
	
	var particle_amounts: Dictionary[String, int] = {
		"Low": low_particle_amount,
		"Medium": medium_particle_amount,
		"High": high_particle_amount
	}
	
	_particle_amount = Config.display.particle_amount
	
	amount = particle_amounts.get(Config.display.particle_amount)
	preprocess = _preprocess
	restart()


func _on_config_changed() -> void:
	if Config.display.particle_amount == _particle_amount:
		return
	
	update_particles()
