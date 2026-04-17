extends LevelObject

@export var falling_speed: float = 200.0
@export var body: StaticBody2D
@export var sprite: SmartSprite2D

var shake: bool = false
var started: bool = false
var falling: bool = false


func _physics_process(delta: float) -> void:
	if shake:
		sprite.offset = Vector2(randi_range(0, 2), 0)
	if falling:
		position.y += falling_speed * delta


func _on_ride_area_new_player_rider(_player: Player) -> void:
	if started:
		return
	
	started = true
	shake = true
	await get_tree().create_timer(1).timeout
	shake = false
	falling = true
	await get_tree().create_timer(3).timeout
	queue_free()
