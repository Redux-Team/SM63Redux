class_name FrictionComponent
extends EntityComponent


@export var base_friction: float = 1.0
@export var multiplier: float = 1.0
@export var scale_factor: float = 1.0


func _physics_process(_delta: float) -> void:
	if enabled and entity.is_on_floor():
		apply()


func apply(factor: float = 1.0, enforce: bool = false) -> void:
	if entity.is_on_floor() or enforce:
		var friction: float = get_effective() * factor
		if abs(entity.velocity.x) <= friction:
			entity.velocity.x = 0.0
		else:
			entity.velocity.x = lerpf(entity.velocity.x, 0.0, friction * 0.25)


func get_effective() -> float:
	return base_friction * multiplier * scale_factor
