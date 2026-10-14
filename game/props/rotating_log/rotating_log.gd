extends Prop

@export var speed: float = 1.0


func _physics_process(delta: float) -> void:
	var pivot: Node2D = self
	if object:
		pivot = object
	pivot.rotate(delta * speed)
