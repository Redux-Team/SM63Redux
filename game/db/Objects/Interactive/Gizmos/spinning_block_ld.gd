@tool
extends LDObject

static var _shared_time: float = 0.0
static var _last_frame: int = -1

@export var block_size: Vector2 = Vector2(32, 32):
	set(bs):
		block_size = bs
		if is_node_ready():
			_update_size()
@export var b_rotate_speed: float = 1.0
@export var b_wait_time: float = 2.0
@export var preview: Control
@export var rect: Control
@export var editor_shape: RectangleShape2D


func _process(delta: float) -> void:
	if not b_rotate_speed:
		return
	if not Engine.is_editor_hint():
		var frame: int = Engine.get_process_frames()
		if _last_frame != frame:
			_last_frame = frame
			_shared_time += delta
	
	if preview:
		preview.rotation_degrees = _calc_degrees(_shared_time)


func _calc_degrees(t: float) -> float:
	var cycle: float = 1.0 / absf(b_rotate_speed)
	var wait_cycle: float = cycle + b_wait_time
	var phase: float = fmod(t, wait_cycle)
	var increment: int = floori(t / wait_cycle)
	var base: float = 90.0 * increment * sign(b_rotate_speed)
	var t_norm: float = minf(phase / cycle, 1.0)
	return wrapf(base + 90.0 * sign(b_rotate_speed) * t_norm, 0.0, 360.0)


func _update_size() -> void:
	if rect:
		rect.position = -(block_size + Vector2(2.0, 2.0)) / 2.0
		rect.size = block_size + Vector2(2.0, 2.0)
		editor_shape.size = rect.size
