extends Node

@export var rect: Control
@export var ghost_source: Control
@export var ghost_alpha: float = 0.46

var _object: GameObject
var _ghost: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_object = GameObject.of(self)
	_ghost = ghost_source.duplicate() as Control
	_ghost.modulate.a = ghost_alpha
	rect.add_child(_ghost)
	rect.move_child(_ghost, 0)


func _process(_delta: float) -> void:
	if _object == null:
		return
	
	_ghost.pivot_offset = _ghost.size * 0.5
	_ghost.rotation_degrees = SpinningBlock.get_degrees(Time.get_ticks_msec() / 1000.0, _object.get_value(&"b_rotate_speed"), _object.get_value(&"b_wait_time"))
