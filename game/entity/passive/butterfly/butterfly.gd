extends Prop

@export var sprite: SmartSprite2D
@export var path_follow_2d: PathFollow2D

var speed: float = randf_range(15.0, 25.0)
var _previous_x: float = 0.0


func _on_init() -> void:
	sprite.play(&"flap")
	path_follow_2d.progress = randf_range(0.0, 300.0)


func _process(delta: float) -> void:
	path_follow_2d.progress += delta * speed
	var moved: float = path_follow_2d.position.x - _previous_x
	if not is_zero_approx(moved):
		sprite.flip_h = moved < 0.0
	
	_previous_x = path_follow_2d.position.x
