## Area responsible for inflicting damage.
@icon("uid://cnxmiusk677bl")
class_name HitBox
extends Area2D

enum DamageType {
	STRIKE,
	SQUISH,
}

## Optional, helps specify what [i]kind[/i] of hitbox this is, useful for differentiating
## between two different hitboxes of the same [member damage_type]. 
@export var hitbox_id: String

@export_group("Damage")
## How much HP will be removed from the affected [Entity].
@export var damage_amount: float
## Which type of damage is being inflicted
@export var damage_type: DamageType

@export_group("Knockback")
## Whether this hitbox inflicts knockback.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "knockback") var has_knockback: bool = false
## The velocity vector added to the entity upon being hit. Positive values knock away relative from
## the source of damage.
@export var knockback_vector: Vector2


func _init() -> void:
	collision_layer = 1 << 4
	collision_mask = 1 << 5
