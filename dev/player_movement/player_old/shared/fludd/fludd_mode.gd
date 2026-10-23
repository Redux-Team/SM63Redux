@abstract class_name FluddModeOld
extends Mode


@export var nozzle: PlayerFluddHandlerOld.FluddNozzle

@export_group("Availability")
@export var blocked_states: Array[StringName] = []

@export_group("Consumption")
@export var drains_power: bool = true
@export var drains_fuel: bool = true
@export var requires_full_power: bool = false
@export var recharge_time: float = 0.0

@export_group("Presentation")
@export var fludd_variant: StringName
@export var plume_animation: StringName
@export var use_animation: StringName
@export var continuous_particles: bool = true

@export_group("Offsets")
@export var plume_offset: Vector2
@export var particle_offset: Vector2


var fludd: PlayerFluddHandlerOld
var player: PlayerOld


func _bind() -> void:
	fludd = host as PlayerFluddHandlerOld
	player = fludd.player


func has_charge() -> bool:
	if requires_full_power:
		return is_equal_approx(
			fludd.fludd_power,
			PlayerFluddHandlerOld.FLUDD_POWER_MAX,
		)
	
	return fludd.fludd_power > 0.0


func is_committing() -> bool:
	return false


func is_aiming() -> bool:
	return false


func _is_available() -> bool:
	for state: StringName in blocked_states:
		if player.machine.is_active(state):
			return false
	
	return true


func get_spray_angle() -> float:
	const RIGHT: float = PI / 2.0
	
	if fludd.get_context() in [
		PlayerFluddHandlerOld.FluddContext.DIVE,
		PlayerFluddHandlerOld.FluddContext.FLOOR_SLIDE,
	]:
		if player.sprite.flip_h:
			return (3.0 * RIGHT) - deg_to_rad(player.sprite.local_rotation)
		
		return RIGHT + deg_to_rad(player.sprite.local_rotation)
	
	return player.sprite.rotation
