@abstract class_name FluddMode
extends Mode

## Nozzle this mode runs for.
@export var nozzle: PlayerFludd.Nozzle
@export_group("Availability")
## States that stop this mode from running.
@export var blocked_states: Array[StringName] = []
@export_group("Consumption")
## Drains FLUDD power while running in the air.
@export var drains_power: bool = true
## Drains water while running outside of water.
@export var drains_fuel: bool = true
## Only runs while power is full.
@export var requires_full_power: bool = false
## Time to recharge from empty to full power in the air while not spraying; zero
## disables recharging.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var recharge_time: float = 0.0
@export_group("Presentation")
## Sprite variant shown on the backpack for this nozzle.
@export var fludd_variant: StringName
## Plume animation played while spraying.
@export var plume_animation: StringName
## Backpack animation played while spraying.
@export var use_animation: StringName
## Shows the water stream while spraying instead of only burst particles.
@export var continuous_spray: bool = true
## Stream settings for this nozzle; the stream's default profile is used when
## empty.
@export var spray: SprayProfile
## Offset of the plume from its default position.
@export var plume_offset: Vector2
## Offset of the spray origin from the plume.
@export var particle_offset: Vector2

## The backpack running this mode.
var fludd: PlayerFludd
## The player wearing the backpack.
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
