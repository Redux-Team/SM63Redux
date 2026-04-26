extends LevelObject

var speed: float = randf_range(15, 25)

@export var sprite: SmartSprite2D
@export var path_follow_2d: PathFollow2D

var _previous_x: float = 0.0


func _ready() -> void:
	sprite.play(&"flap")
	path_follow_2d.progress = randf_range(0, 300)


func _process(delta: float) -> void:
	path_follow_2d.progress += delta * speed
	
	if path_follow_2d.position.x - _previous_x > 0:
		sprite.flip_h = false
	elif path_follow_2d.position.x - _previous_x < 0:
		sprite.flip_h = true
		
	_previous_x = path_follow_2d.position.x
