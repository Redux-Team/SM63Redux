@warning_ignore_start("unused_signal")
class_name HealthComponent
extends EntityComponent


signal hp_updated(hp: float)
signal power_updated(power: int)
signal power_reset()
signal damaged(amount: float, type: HitBox.DamageType)
signal died

@export var max_hp: float = 1.0
## Rounds to the nearest health point when healing or taking damage.
@export var round_to_nearest: bool = true
@export_group("Player")
@export var power: int = 0:
	set(p):
		if is_equal_approx(_hp, max_hp):
			power = 0
			return
		
		@warning_ignore("integer_division")
		var heals: int = p / power_max
		var remainder: int = p % power_max
		if heals > 0:
			power_reset.emit()
			heal(float(heals), 0.2)
		power = remainder
		power_updated.emit(power)
@export var power_max: int = 5
var hp_tween: Tween

var _hp: float:
	set(hp):
		# We healed up
		if roundf(_hp) >= roundf(max_hp) and power > 0:
			power = 0
			power_reset.emit()
		
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


func heal(amount: float, time: float = 0.0) -> void:
	if time > 0.0:
		var tween: Tween = create_tween()
		tween.tween_property(self, ^"_hp", _hp + amount, time)
		return
	
	_hp += amount
	if round_to_nearest:
		_hp = roundf(_hp)


func heal_percentage(amount: float, time: float = 0.0) -> void:
	var heal_amount: float = max_hp * amount
	var tween: Tween = create_tween()
	tween.tween_property(self, "_hp", _hp + heal_amount, time)


func set_hp(amount: float) -> void:
	_hp = amount
