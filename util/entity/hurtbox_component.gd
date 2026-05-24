@icon("uid://dl48gyw37ryc4")
class_name HurtBoxComponent
extends Resource

enum KnockbackMode {
	PASSTHROUGH, 
	SET_RELATIVE,
	SET_ABSOLUTE,
	ADD_RELATIVE,
	ADD_ABSOLUTE,
}

@export_group("Filters")
@export var accepted_hitbox_ids: PackedStringArray
@export var ignored_hitbox_ids: PackedStringArray
@export var accepted_damage_types: Array[HitBox.DamageType]
@export var ignored_damage_types: Array[HitBox.DamageType]
@export_custom(PROPERTY_HINT_EXPRESSION, "") var expression: String

@export_group("Knockback")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "knockback") var override_knockback: bool = false
@export var knockback: Vector2 = Vector2(150, 135)
@export var knockback_mode_x: KnockbackMode = KnockbackMode.SET_RELATIVE
@export var knockback_mode_y: KnockbackMode = KnockbackMode.SET_ABSOLUTE

@export_group("Damage State")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var override_damage_state: bool = false
@export var damage_state_map: Dictionary[HitBox.DamageType, StringName]
@export var damage_state_name: StringName


func matches(hitbox: HitBox, hurtbox: HurtBox = null, entity: Entity = null) -> bool:
	if accepted_hitbox_ids and not hitbox.hitbox_ids.any(func(id: String) -> bool: return id in accepted_hitbox_ids):
		return false
	if hitbox.hitbox_ids.any(func(id: String) -> bool: return id in ignored_hitbox_ids):
		return false
	if accepted_damage_types and hitbox.damage_type not in accepted_damage_types:
		return false
	if hitbox.damage_type in ignored_damage_types:
		return false
	if not expression.is_empty():
		var expr: Expression = Expression.new()
		var err: Error = expr.parse(expression, [&"hitbox", &"hurtbox", &"entity"])
		if err != OK:
			push_error("HurtBoxComponent: failed to parse expression: %s" % expr.get_error_text())
			return false
		var result: Variant = expr.execute([hitbox, hurtbox, entity])
		if expr.has_execute_failed():
			push_error("HurtBoxComponent: failed to execute expression: %s" % expr.get_error_text())
			return false
		return result as bool
	return true


func process(hitbox: HitBox, hurtbox: HurtBox, entity: Entity) -> void:
	if entity.has_component(HealthComponent):
		var health_component: HealthComponent = entity.get_component(HealthComponent)
		
		if not hitbox.damage_curve:
			health_component.damage(hitbox.damage_amount, hitbox.damage_type)
		else:
			var dist: float = hitbox.global_position.distance_to(hurtbox.global_position)
			health_component.damage(hitbox.damage_curve.sample(dist), hitbox.damage_type)
		
		entity.velocity = _resolve_knockback(hitbox, hurtbox, entity.velocity)
		
		var state: StringName = _resolve_damage_state(hitbox, hurtbox)
		if not state.is_empty() and entity.state_machine:
			entity.state_machine.change_state(state)


func _resolve_knockback(hitbox: HitBox, hurtbox: HurtBox, current_velocity: Vector2) -> Vector2:
	var dir: Vector2 = sign(hitbox.global_position - hurtbox.global_position)
	var base: Vector2 = current_velocity
	
	if hitbox.has_knockback:
		base = -hitbox.knockback_vector * dir
	elif hurtbox.has_default_knockback:
		base = -hurtbox.default_knockback * dir
	
	if not override_knockback:
		return base
	
	var result: Vector2 = base
	
	for axis: int in 2:
		var mode: KnockbackMode = knockback_mode_x if axis == 0 else knockback_mode_y
		match mode:
			KnockbackMode.PASSTHROUGH:
				result[axis] = base[axis]
			KnockbackMode.SET_RELATIVE:
				result[axis] = -knockback[axis] * dir[axis]
			KnockbackMode.SET_ABSOLUTE:
				result[axis] = -knockback[axis]
			KnockbackMode.ADD_RELATIVE:
				result[axis] = base[axis] + (-knockback[axis] * dir[axis])
			KnockbackMode.ADD_ABSOLUTE:
				result[axis] = base[axis] + (-knockback[axis])
	
	return result


func _resolve_damage_state(hitbox: HitBox, hurtbox: HurtBox) -> StringName:
	if override_damage_state:
		if hitbox.damage_type in damage_state_map:
			return damage_state_map[hitbox.damage_type]
		if not damage_state_name.is_empty():
			return damage_state_name
	return hurtbox.default_damage_state
