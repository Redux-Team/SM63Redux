extends Node2D

@export var source: Control
@export var speed: float = 1.0
@export var ghost_alpha: float = 0.5

var _ghost: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	modulate.a = ghost_alpha
	_ghost = source.duplicate() as Control
	add_child(_ghost)


func _process(delta: float) -> void:
	rotation += delta * speed
	_ghost.size = source.size
	_ghost.position = source.position
