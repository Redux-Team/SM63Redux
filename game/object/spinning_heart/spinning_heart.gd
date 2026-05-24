extends LevelObject


@export var healing_curve: Curve
@export var sprite: SmartSprite2D
@export var heal_sfx: AudioStreamPlayer2D

var speed_scale: float = 1.0


func _ready() -> void:
	sprite.play()


func _on_entity_check_area_player_entered(player: Player) -> void:
	if abs(player.velocity.x) >= 170:
		# this is from 0.0 - 1.0
		var heal_percentage: float = healing_curve.sample(abs(player.velocity.x))
		var health_component: HealthComponent = player.get_component(HealthComponent)
		
		if health_component.get_hp() < health_component.max_hp:
			player.heal_particles.show()
			player.heal_particles.emitting = true
			heal_sfx.play()
		
		health_component.heal_percentage(heal_percentage, 0.5)
		
		speed_scale = heal_percentage * 60


func _physics_process(_delta: float) -> void:
	speed_scale = lerpf(speed_scale, 1.0, 0.04)
	sprite.speed_scale = speed_scale
