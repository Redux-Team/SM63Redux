extends LevelObject

const SHAKE_DURATION: float = 1.0
const SHAKE_OFFSET: int = 2
const CLEANUP_DELAY: float = 3.0

@export var falling_speed: float = 200.0
@export var sprite: SmartSprite2D

var _shaking: bool = false
var _falling: bool = false
var _triggered: bool = false


func _physics_process(delta: float) -> void:
	if _shaking:
		sprite.offset = Vector2(randi_range(0, SHAKE_OFFSET), 0)
	if _falling:
		position.y += falling_speed * delta


func _on_ride_area_new_player_rider(_player: Player) -> void:
	if _triggered:
		return
	
	_triggered = true
	_shaking = true
	await get_tree().create_timer(SHAKE_DURATION).timeout
	_shaking = false
	_falling = true
	await get_tree().create_timer(CLEANUP_DELAY).timeout
	queue_free()
