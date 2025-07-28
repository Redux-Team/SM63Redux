class_name GravityComponent
extends Component

@export var gravity_strength: float = 15.0


func _physics_process(delta: float) -> void:
	entity.velocity.y += gravity_strength
