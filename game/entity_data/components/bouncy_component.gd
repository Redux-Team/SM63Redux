class_name BouncyComponent
extends EntityComponent

@export var restitution: float = 0.6
@export var min_velocity: float = 50.0


var _prev_velocity_y: float = 0.0


func _physics_process(_delta: float) -> void:
	if enabled and entity:
		if entity.is_on_floor() and _prev_velocity_y > 0.0:
			apply(_prev_velocity_y)
		_prev_velocity_y = entity.velocity.y


func apply(impact_velocity: float = _prev_velocity_y) -> void:
	if impact_velocity >= min_velocity:
		entity.velocity.y = -impact_velocity * restitution
	else:
		entity.velocity.y = 0.0


func get_effective() -> float:
	return restitution
