@abstract class_name Entity
extends CharacterBody2D
@warning_ignore_start("unused_parameter")

enum DamageType {
	GENERIC,
	SQUASH,
	STRIKE
}

@export var sprite: AnimatedSprite2D

@export_group("Components")

@export_subgroup("Health", "")
## Whether the entity has HP and, in turn, whether it can die.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var has_heath: bool = true
## The amount of health the entity has.
@export var hp: float = 1.0

@export_subgroup("Gravity", "")
## Whether the entity is affected by gravity or not. Although disabling this can be useful
## when implementing custom gravity solutions, overriding [method _gravity_handler] is
## preferred.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var has_gravity: bool = true
## How effective gravity is on the entity, i.e., how fast the entity will fall.
@export var gravity_strength: float = 15.0
## A multiplier of [member gravity_strength], this can be useful when creating gravity zones
## or areas where gravity must be changed whilst preserving the original gravity strength.
@export var gravity_scale_factor: float = 1.0


@export_subgroup("Friction", "")
## Whether the entity is affected by friction or not. 
## [br][br]
## [b]Note:[/b] disabling this component does [b]not[/b] disable friction, 
## rather just makes entities immediately [u]stop[/u] as opposed to slowing down. 
## To "disable" friction for endless sliding, set [member base_friction] or
## [member friction_multiplier] to [code]0.0[/code].
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var has_friction: bool = true
## The base amount of friction. This would normally not be modified mid-game, as
## this is more of a base character attribute.
@export var base_friction: float = 1.0
## A multiplier for [member base_friction]
@export var friction_multiplier: float = 1.0


@export_subgroup("Invulnerable")
## Determines whether the entity is able to receive damage from the [method damage] method.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var is_invulnerable: bool = false
## The types of damage that the invulnerability does not apply to.
@export var invulnerability_exceptions: Array[DamageType]


func _physics_process(delta: float) -> void:
	_on_tick(delta)
	if Engine.is_editor_hint():
		return
	if has_gravity: _gravity_handler()
	move_and_slide()

## Uses the [b]health component[/b]. Reduces the entity's HP by [param amount].
func damage(amount: float, type: DamageType, source: Node2D = null) -> void:
	if not is_invulnerable:
		force_damage(amount, type, source)

## Similar to [method damage], but does not check for invulnerability. 
func force_damage(amount: float, type: DamageType, source: Node2D = null) -> void:
	hp -= amount
	_on_damage(amount, type, source)
	if hp <= 0:
		_on_death(type, source)

## Sets the entity's HP to zero, regardless of whether [member is_invulnerable] is enabled or not.
## Does nothing if the [b]health component[/b] is disabled.
func kill() -> void:
	if has_heath:
		hp = 0
		_on_death(DamageType.GENERIC)

## Uses the [b]friction component[/b]. Returns the effective friction multiplier.
func get_effective_friction() -> float:
	return base_friction * friction_multiplier

## Uses the [b]friction component[/b]. Helper function to automatically apply
## friction.
func apply_friction() -> void:
	if is_on_floor():
		var friction: float = get_effective_friction()
		
		if abs(velocity.x) <= friction or not has_friction:
			velocity.x = 0
		else:
			velocity.x = lerpf(velocity.x, 0, friction * 0.25)


## Called every tick of the physics process, does not override any internal processing.
func _on_tick(delta: float) -> void:
	pass

## Called when the entity's HP becomes 0.
func _on_death(type: DamageType, source: Node2D = null) -> void:
	queue_free()

## Called when the entity receives damage.
func _on_damage(amount: float, type: DamageType, source: Node2D = null) -> void:
	pass

## Handles the gravity of the entity. By default, this accelerates the entity's y-component
## of the velocity by [code]gravity_strength * gravity_scale_factor[/code].
func _gravity_handler() -> void:
	if not is_on_floor():
		velocity.y += gravity_strength * gravity_scale_factor
