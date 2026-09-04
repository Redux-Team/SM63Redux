extends LevelObject


const MIN_HEAL_SPEED: float = 170.0
const SPIN_BURST_SCALE: float = 60.0
const SPIN_DECAY: float = 0.04
const HEAL_DURATION: float = 0.5

@export var healing_curve: Curve
@export var sprite: SmartSprite2D
@export var heal_sfx: AudioStreamPlayer2D

var _spin_speed: float = 1.0


func _ready() -> void:
	sprite.play()


func _physics_process(_delta: float) -> void:
	_spin_speed = lerpf(_spin_speed, 1.0, SPIN_DECAY)
	sprite.speed_scale = _spin_speed


func _on_entity_check_area_player_entered(player: Player) -> void:
	var speed: float = absf(player.velocity.x)
	if speed < MIN_HEAL_SPEED:
		return
	
	# this is from 0.0 - 1.0
	var heal_percentage: float = healing_curve.sample(speed)
	var health_component: HealthComponent = player.get_component(HealthComponent)
	
	if health_component.get_hp() < health_component.max_hp:
		player.heal_particles.show()
		player.heal_particles.emitting = true
		heal_sfx.play()
	
	health_component.heal_percentage(heal_percentage, HEAL_DURATION)
	_spin_speed = heal_percentage * SPIN_BURST_SCALE
