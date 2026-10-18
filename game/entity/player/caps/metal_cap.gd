class_name MetalCap
extends CapMode

@export var animation_overrides: Dictionary[StringName, StringName] = {}
@export var footstep_terrain: StringName = &"metal"
@export_group("Movement")
@export var ground_speed_scale: float = 1.0
@export var air_speed_scale: float = 1.0
@export var jump_strength_scale: float = 1.0
@export var shake_scale: float = 1.0
@export_group("Water")
@export var water_gravity_scale: float = 1.0
@export var water_entry_damping: float = 1.0
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var water_max_fall_speed: float = 0.0
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var water_pound_fall_speed: float = 0.0
@export_group("Damage")
@export var damage_scale: float = 1.0
@export var knockback_scale: float = 1.0
@export var recovery_scale: float = 1.0


func get_animation_override(animation: StringName) -> StringName:
	return animation_overrides.get(animation, animation)


func get_footstep_terrain() -> StringName:
	return footstep_terrain


func get_water_fall_speed(pounding: bool) -> float:
	return water_pound_fall_speed if pounding and water_pound_fall_speed > 0.0 else water_max_fall_speed


func ignores_water() -> bool:
	return true
