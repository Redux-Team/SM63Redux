@warning_ignore_start("unused_signal")
class_name HealthComponent
extends EntityComponent


signal died
signal damaged(amount: float, type: Entity.DamageType)

@export var max_hp: float = 1.0
@export var hitbox: HitBox


var hp: float:
	set(value):
		hp = value
		if hp <= 0.0:
			died.emit()
