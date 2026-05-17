@icon("uid://cnxmiusk677bl")
class_name HitBox
extends Area2D

enum DamageType {
	GENERIC,
	STRIKE,
	SQUISH,
}

@export_group("Identity")
## Optional, helps specify what [i]kind[/i] of hitbox this is, useful for differentiating
## between two different hitboxes of the same [member damage_type].
@export var hitbox_ids: Array[String]
@export_custom(PROPERTY_HINT_EXPRESSION, "") var hit_expression: String

@export_group("Damage")
## How much HP will be removed from the affected [Entity].
@export var damage_amount: float
## Which type of damage is being inflicted
@export var damage_type: DamageType
@export var damage_curve: Curve

@export_group("Knockback")
## Whether this hitbox inflicts knockback.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "knockback") var has_knockback: bool = false
## The velocity vector added to the entity upon being hit. Positive values knock away relative from
## the source of damage.
@export var knockback_vector: Vector2 = Vector2(150, 135)


func _init() -> void:
	collision_layer = 1 << 4
	collision_mask = 1 << 5


func is_valid() -> bool:
	if hit_expression.is_empty():
		return true
	var e: Expression = Expression.new()
	e.parse(hit_expression)
	var result: Variant = e.execute([], owner)
	if e.has_execute_failed():
		return false
	return bool(result)


func enable(time: float = 0.0) -> void:
	for c: Node in get_children():
		if c is CollisionShape2D or c is CollisionPolygon2D:
			c.set_deferred(&"disabled", false)
	set_deferred(&"monitorable", true)
	
	if time:
		await get_tree().create_timer(time).timeout
		disable()


func disable() -> void:
	for c: Node in get_children():
		if c is CollisionShape2D or c is CollisionPolygon2D:
			c.set_deferred(&"disabled", true)
	set_deferred(&"monitorable", false)
