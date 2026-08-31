extends CheepCheepState


const DEATH_DELAY: float = 0.6

@export var friction_component: FrictionComponent
@export var hit_box_shape: CollisionShape2D
@export var hurt_box_shape: CollisionShape2D

var t: Tween


func _enter() -> void:
	friction_component.enabled = true
	hit_box_shape.set_deferred(&"disabled", true)
	hurt_box_shape.set_deferred(&"disabled", true)
	t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(sprite, "rotation_degrees", 270.0, 1.0)


func _tick(_delta: float) -> void:
	if cheep_cheep.is_in_water():
		cheep_cheep.velocity = lerp(cheep_cheep.velocity, Vector2.ZERO, 0.08)
		if time > DEATH_DELAY:
			cheep_cheep.queue_free()
	elif time > DEATH_DELAY and cheep_cheep.is_on_floor():
		cheep_cheep.queue_free()
