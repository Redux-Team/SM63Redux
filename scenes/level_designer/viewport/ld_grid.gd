class_name LDGrid
extends LDComponent

const ALPHA_EPSILON: float = 1.0 / 255.0

@export var canvas: Node2D
@export var texture: Texture2D
@export var cell_modulate: Color = Color(0.0, 0.0, 0.0, 0.2)
@export var origin_modulate: Color = Color(0.0, 0.0, 0.0, 1.0)
@export_range(0.0, 4.0) var fade_threshold: float = 1.0

var _layer: LevelLayer
var _blend: float = 1.0
var _blend_tween: Tween
var _from: Transform2D
var _drawn: Transform2D
var _state: Array = []


func _setup() -> void:
	canvas.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	canvas.draw.connect(_on_draw)
	canvas.tree_entered.connect(_invalidate)
	editor.level_handler.layer_changed.connect(_on_layer_changed)


func _invalidate() -> void:
	_state.clear()


func _process(_delta: float) -> void:
	if not _is_drawable(_layer):
		return
	
	canvas.z_index = _layer.z_index - (LevelLayer.Z_STRIDE >> 1)
	var state: Array = [_target_transform(), editor.world.get_canvas_transform(), canvas.get_viewport_rect().size, _blend]
	if state == _state:
		return
	
	_state = state
	canvas.queue_redraw()


func _on_layer_changed(layer: LevelLayer) -> void:
	if layer == _layer:
		return
	
	var animate: bool = _is_drawable(_layer) and Settings.ui.animations.current_value and not editor.level_handler.focus_enabled
	_layer = layer
	if _blend_tween and _blend_tween.is_valid():
		_blend_tween.kill()
	
	if not animate:
		_blend = 1.0
		return
	
	_from = _drawn
	_blend = 0.0
	_blend_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_blend_tween.tween_property(self, ^"_blend", 1.0, editor.level_handler.depth_duration)


func _on_draw() -> void:
	if not _is_drawable(_layer):
		return
	
	var layer_transform: Transform2D = _target_transform()
	if _blend < 1.0:
		layer_transform = _from.interpolate_with(layer_transform, _blend)
	
	_drawn = layer_transform
	
	var view_transform: Transform2D = editor.world.get_canvas_transform()
	var view_size: Vector2 = canvas.get_viewport_rect().size
	var cell: Vector2 = texture.get_size()
	var to_screen: Transform2D = view_transform * layer_transform
	var fade: float = smoothstep(0.0, fade_threshold, absf(to_screen.get_scale().x))
	var tint: Color = Color(cell_modulate, cell_modulate.a * fade)
	canvas.draw_set_transform_matrix(layer_transform)
	if tint.a > ALPHA_EPSILON:
		var view: Rect2 = to_screen.affine_inverse() * Rect2(Vector2.ZERO, view_size)
		var start: Vector2 = (view.position / cell).floor() * cell
		var end: Vector2 = (view.end / cell).ceil() * cell
		canvas.draw_texture_rect(texture, Rect2(start, end - start), true, tint)
	
	canvas.draw_texture_rect(texture, Rect2(-cell, cell), false, origin_modulate)


func _target_transform() -> Transform2D:
	return Transform2D.IDENTITY if editor.level_handler.focus_enabled else _transform_of(_layer)


func _transform_of(layer: Variant) -> Transform2D:
	return (layer as LevelLayer).get_objects_root().get_global_transform() if _is_drawable(layer) else Transform2D.IDENTITY


func _is_drawable(layer: Variant) -> bool:
	return is_instance_valid(layer) and (layer as Node).is_inside_tree()
