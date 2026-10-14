@tool
@icon("uid://nflw8vbs4mrj")
class_name Background
extends CanvasLayer


@export var background_texture: Texture2D:
	set(bt):
		background_texture = bt
		_refresh_background()
@export var autoscroll: Vector2 = Vector2.ZERO:
	set(a):
		autoscroll = a
		_refresh_background()
@export var follow_camera: bool = true:
	set(fc):
		follow_camera = fc
		_refresh_background()
@export var layers: Array[BackgroundLayer]:
	set(l):
		layers = l
		_refresh_background()

var _active: Array[BackgroundLayer] = []
var _backdrop: Parallax2D
var _visible_size: Vector2
var _content_scale: float = 1.0
var _dirty: bool = false


func _ready() -> void:
	_refresh_background()


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		_refresh_background()
	var content_scale: float = _get_content_scale()
	var size: Vector2 = _get_visible_size(content_scale)
	if size == _visible_size and content_scale == _content_scale:
		return
	_visible_size = size
	_content_scale = content_scale
	_update_background()


func _queue_refresh() -> void:
	_dirty = true


func _validate_property(property: Dictionary) -> void:
	if property.name in [&"follow_viewport_enabled", &"follow_viewport_scale"]:
		property.usage = PROPERTY_USAGE_NONE


#func _get_configuration_warnings() -> PackedStringArray:
	#if get_children(true).filter(func(c: Node) -> bool: return c is not BackgroundNode):
		#return ["This node cannot have children!"]
	#return []


func _refresh_background() -> void:
	if not is_node_ready():
		return
	follow_viewport_enabled = false
	for bg_layer: BackgroundLayer in _active:
		if bg_layer.changed.is_connected(_queue_refresh):
			bg_layer.changed.disconnect(_queue_refresh)
	_active.clear()
	_backdrop = null
	for child: Node in get_children(true):
		remove_child(child)
		child.queue_free()
	if background_texture:
		_backdrop = _build_backdrop()
		_backdrop.follow_viewport = false
		add_child(_backdrop, false, INTERNAL_MODE_FRONT)
	for bg_layer: BackgroundLayer in layers:
		if not bg_layer:
			continue
		if not bg_layer.changed.is_connected(_queue_refresh):
			bg_layer.changed.connect(_queue_refresh)
		var node: Node = bg_layer._build()
		for parallax: Parallax2D in BackgroundLayerGroup.collect_parallax(node):
			parallax.ignore_camera_scroll = not follow_camera
			parallax.follow_viewport = false
			parallax.autoscroll += autoscroll
		add_child(node, false, INTERNAL_MODE_FRONT)
		_active.append(bg_layer)
	_content_scale = _get_content_scale()
	_visible_size = _get_visible_size(_content_scale)
	_update_background()


func _build_backdrop() -> Parallax2D:
	var parallax: Parallax2D = Parallax2D.new()
	parallax.scroll_scale = Vector2.ZERO
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = background_texture
	sprite.centered = false
	parallax.add_child(sprite)
	return parallax


func _update_background() -> void:
	scale = Vector2.ONE / _content_scale
	var visible_rect: Rect2 = Rect2(Vector2.ZERO, _visible_size)
	var bg_offset: int = 0
	if _backdrop:
		var sprite: Sprite2D = _backdrop.get_child(0)
		sprite.scale = _visible_size / background_texture.get_size()
		bg_offset = 1
	for i: int in _active.size():
		_active.get(i)._update(get_child(i + bg_offset, true), visible_rect)


func _get_visible_size(content_scale: float) -> Vector2:
	var viewport: Viewport = get_viewport()
	if Engine.is_editor_hint() or not viewport:
		return _get_design_size()
	return viewport.get_visible_rect().size * content_scale


func _get_content_scale() -> float:
	var window: Window = get_viewport() as Window
	if Engine.is_editor_hint() or not window:
		return 1.0
	return window.content_scale_factor


func _get_design_size() -> Vector2:
	var width: int = ProjectSettings.get_setting_with_override(&"display/window/size/viewport_width")
	var height: int = ProjectSettings.get_setting_with_override(&"display/window/size/viewport_height")
	return Vector2(width, height)


class BackgroundNode:
	extends Node
