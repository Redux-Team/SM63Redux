@warning_ignore_start("unused_signal")
class_name HealthComponent
extends EntityComponent


signal died
signal damaged(amount: float, type: HitBox.DamageType)

@export var max_hp: float = 1.0
@export var hitbox: HitBox


var _hp: float


func _ready() -> void:
	set_hp(max_hp)


func get_hp() -> float:
	return _hp


func damage(amount: float, type: HitBox.DamageType) -> void:
	_hp -= amount
	
	damaged.emit(amount, type)
	
	if _hp <= 0:
		died.emit()
	


func set_hp(amount: float) -> void:
	_hp = amount
