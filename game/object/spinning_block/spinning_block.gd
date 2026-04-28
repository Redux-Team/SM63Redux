extends LevelObject

@export var rect: Control
@export var spinning_block: RectangleShape2D

var b_size_x: float
var b_size_y: float
var block_size: Vector2
var b_rotate_speed: float
var b_wait_time: float


func _on_init() -> void:
	block_size = Vector2(b_size_x, b_size_y)
	_update_size()


func _process(_delta: float) -> void:
	if not b_rotate_speed:
		return
	rect.rotation_degrees = _calc_degrees(Singleton.get_level_clock().get_elapsed_time())


func _calc_degrees(t: float) -> float:
	var cycle: float = 1.0 / absf(b_rotate_speed)
	var wait_cycle: float = cycle + b_wait_time
	var phase: float = fmod(t, wait_cycle)
	var increment: int = floori(t / wait_cycle)
	var base: float = 90.0 * increment * sign(b_rotate_speed)
	var t_norm: float = clampf((phase - b_wait_time) / cycle, 0.0, 1.0)
	return wrapf(base + 90.0 * sign(b_rotate_speed) * t_norm, 0.0, 360.0)


func _update_size() -> void:
	rect.position = -(block_size + Vector2(2.0, 2.0)) / 2.0
	rect.size = block_size + Vector2(2.0, 2.0)
	if spinning_block:
		spinning_block.size = block_size + Vector2(2.0, 2.0)
