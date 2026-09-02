extends CheepCheepState


const DEATH_DELAY: float = 0.6
const SPIN_OUT_DEGREES: float = 270.0
const SPIN_OUT_DURATION: float = 1.0
const SINK_WEIGHT: float = 0.08

@export var friction_component: FrictionComponent
@export var hit_box_shape: CollisionShape2D
@export var hurt_box_shape: CollisionShape2D


func _enter() -> void:
	friction_component.enabled = true
	hit_box_shape.set_deferred(&"disabled", true)
	hurt_box_shape.set_deferred(&"disabled", true)
	
	var tween: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(sprite, "rotation_degrees", SPIN_OUT_DEGREES, SPIN_OUT_DURATION)


func _tick(_delta: float) -> void:
	if cheep_cheep.is_in_water():
		cheep_cheep.velocity = lerp(cheep_cheep.velocity, Vector2.ZERO, SINK_WEIGHT)
		if time > DEATH_DELAY:
			cheep_cheep.queue_free()
	elif time > DEATH_DELAY and cheep_cheep.is_on_floor():
		cheep_cheep.queue_free()
