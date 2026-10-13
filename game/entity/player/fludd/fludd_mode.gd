@abstract class_name FluddMode
extends Mode

@export var nozzle: PlayerFludd.Nozzle
@export_group("Availability")
@export var blocked_states: Array[StringName] = []
@export_group("Consumption")
@export var drains_power: bool = true
@export var drains_fuel: bool = true
@export var requires_full_power: bool = false
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var recharge_time: float = 0.0
@export_group("Presentation")
@export var fludd_variant: StringName
@export var plume_animation: StringName
@export var use_animation: StringName
@export var continuous_spray: bool = true
@export var spray: SprayProfile
@export var plume_offset: Vector2
@export var particle_offset: Vector2

var fludd: PlayerFludd
var player: Player


func _bind() -> void:
	fludd = host as PlayerFludd
	player = fludd.player


func _is_available() -> bool:
	for state: StringName in blocked_states:
		if player.machine.is_active(state):
			return false
	
	return true


func has_charge() -> bool:
	if requires_full_power:
		return is_equal_approx(fludd.power, PlayerFludd.POWER_MAX)
	return fludd.power > 0.0


func is_committing() -> bool:
	return false


func is_aiming() -> bool:
	return false


func get_spray_angle() -> float:
	if fludd.get_context() not in [PlayerFludd.Context.DIVE, PlayerFludd.Context.FLOOR_SLIDE]:
		return player.sprite.rotation
	if player.sprite.flip_h:
		return 1.5 * PI - deg_to_rad(player.sprite.local_rotation)
	return 0.5 * PI + deg_to_rad(player.sprite.local_rotation)
