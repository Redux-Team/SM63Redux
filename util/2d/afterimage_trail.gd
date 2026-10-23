class_name AfterimageTrail
extends Node2D

@export var source: Node2D
@export var ghost_material: Material
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var interval: float = 0.07
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var lifetime: float = 0.25
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var min_speed: float = 40.0
@export_range(0.0, 1.0, 0.01) var start_alpha: float = 0.85
@export_range(0.0, 1.0, 0.01) var end_alpha: float = 0.0
@export var hue_speed: float = 2.0
@export_range(0.0, 1.0, 0.01) var saturation: float = 0.8
@export_range(0.0, 1.0, 0.01) var value: float = 1.0

var lifetime_scale: float = 1.0

var _cooldown: float = 0.0
var _last_position: Vector2
var _container: Node2D


func _ready() -> void:
	_last_position = source.global_position


func _physics_process(delta: float) -> void:
	var speed: float = source.global_position.distance_to(_last_position) / delta
	_last_position = source.global_position
	_cooldown -= delta
	if _cooldown > 0.0 or speed < min_speed or lifetime_scale <= 0.01:
		return
	
	_cooldown = interval
	var hue: float = fmod(Time.get_ticks_msec() / 1000.0 * hue_speed, 1.0)
	for sprite: Sprite2D in _collect(source):
		_spawn(sprite, Color.from_hsv(hue, saturation, value, start_alpha))


func _exit_tree() -> void:
	if is_instance_valid(_container) and _container.get_parent() != self:
		_container.queue_free()


func _spawn(sprite: Sprite2D, color: Color) -> void:
	var ghost: Sprite2D = Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.centered = sprite.centered
	ghost.offset = sprite.offset
	ghost.flip_h = sprite.flip_h
	ghost.flip_v = sprite.flip_v
	ghost.hframes = sprite.hframes
	ghost.vframes = sprite.vframes
	ghost.frame = sprite.frame
	ghost.region_enabled = sprite.region_enabled
	ghost.region_rect = sprite.region_rect
	ghost.material = ghost_material
	ghost.modulate = color
	ghost.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	ghost.process_mode = Node.PROCESS_MODE_ALWAYS
	_get_container().add_child(ghost)
	ghost.global_transform = sprite.global_transform
	var tween: Tween = ghost.create_tween()
	tween.tween_property(ghost, ^"modulate:a", end_alpha, lifetime * lifetime_scale)
	tween.tween_callback(ghost.queue_free)


func _get_container() -> Node2D:
	if is_instance_valid(_container):
		return _container
	
	var anchor: Node = owner if owner else self
	_container = Node2D.new()
	_container.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if anchor.get_parent():
		anchor.get_parent().add_child(_container)
		anchor.get_parent().move_child(_container, anchor.get_index())
	else:
		add_child(_container)
	
	return _container


func _collect(node: Node) -> Array[Sprite2D]:
	var sprites: Array[Sprite2D] = []
	if node is CanvasItem and not (node as CanvasItem).visible:
		return sprites
	
	if node is Sprite2D and (node as Sprite2D).texture:
		sprites.append(node)
	
	for child: Node in node.get_children():
		sprites.append_array(_collect(child))
	
	return sprites
