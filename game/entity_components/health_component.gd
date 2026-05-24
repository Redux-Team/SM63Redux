@warning_ignore_start("unused_signal")
class_name HealthComponent
extends EntityComponent


signal hp_updated(hp: float)
signal damaged(amount: float, type: HitBox.DamageType)
signal died

@export var max_hp: float = 1.0
## Rounds to the nearest health point when healing or taking damage.
@export var round_to_nearest: bool = true
var hp_tween: Tween

var _hp: float:
	set(hp):
		_hp = clamp(hp, 0, max_hp)
		hp_updated.emit(hp)


func _ready() -> void:
	set_hp(max_hp)


func get_hp() -> float:
	return _hp


func damage(amount: float, type: HitBox.DamageType) -> void:
	_hp -= amount
	
	if round_to_nearest:
		_hp = roundf(_hp)
	
	damaged.emit(amount, type)
	
	if _hp <= 0:
		died.emit()


func heal(amount: float) -> void:
	_hp += amount
	if round_to_nearest:
		_hp = roundf(_hp)


func heal_percentage(amount: float, time: float = 0.0) -> void:
	var heal_amount: float = max_hp * amount
	var tween: Tween = create_tween()
	tween.tween_property(self, "_hp", _hp + heal_amount, time)


func set_hp(amount: float) -> void:
	_hp = amount
