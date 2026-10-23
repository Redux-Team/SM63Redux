extends Node2D

const GHOST_ALPHA: float = 0.3

@export var texture: Texture2D
@export var margin_left: int = 10
@export var margin_right: int = 10

var _object: GameObject
var _rest: Node2D
var _ghosts: Node2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_object = GameObject.of(self)
	_rest = Node2D.new()
	_ghosts = Node2D.new()
	_ghosts.modulate.a = GHOST_ALPHA
	add_child(_ghosts)
	add_child(_rest)
	if _object:
		_object.value_changed.connect(_rebuild.unbind(2))
	_rebuild()


func _process(delta: float) -> void:
	if _object == null:
		return
	
	_ghosts.rotation += delta * float(_object.get_value(&"platform_period"))
	for container: Node2D in [_rest, _ghosts]:
		for platform: Node2D in container.get_children():
			platform.global_rotation = 0.0


func _rebuild() -> void:
	if _object == null:
		return
	
	for container: Node2D in [_rest, _ghosts]:
		for child: Node in container.get_children():
			child.free()
		for offset: Vector2 in MovingPlatform.get_offsets(
				_object.get_value(&"platform_amount"),
				_object.get_value(&"platform_radius"),
		):
			var holder: Node2D = Node2D.new()
			holder.position = offset
			holder.add_child(
					MovingPlatform.build_visual(
							texture,
							margin_left,
							margin_right,
							_object.get_value(&"platform_width"),
					)
			)
			container.add_child(holder)
	
	queue_redraw()
