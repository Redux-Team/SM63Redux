class_name LDViewport
extends LDComponent

const LINEAR_PAN_SPEED: float = 10.0
const CAMERA_ZOOM_MIN: Vector2 = Vector2(0.2, 0.2)
const CAMERA_ZOOM_MAX: Vector2 = Vector2(4.0, 4.0)

## Emits when the viewport is moved and/or zoomed.
signal viewport_moved(pos: Vector2, zoom: Vector2)


@export var camera: Camera2D
@export_group("Internal")
@export var _layers_root: Node2D
@export var _viewport_bg: ColorRect
@export var _root: Node2D


var allow_panning: bool = true
var allow_zooming: bool = true
var camera_position: Vector2 = Vector2.ZERO:
	set(cp):
		camera_position = cp
		camera.position = camera_position
var camera_zoom: Vector2 = Vector2.ONE:
	set(cz):
		camera_zoom = clamp(cz, CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
		camera.zoom = camera_zoom

var is_refocusing: bool = false
var is_mouse_panning: bool = false:
	set(mp):
		Input.set_default_cursor_shape(Input.CURSOR_MOVE if mp else Input.CURSOR_ARROW)
		is_mouse_panning = mp


func _on_ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_moved)
	viewport_moved.connect(_on_viewport_moved)
	_on_viewport_moved(camera_position, camera_zoom)


func _process(_delta: float) -> void:
	if not has_input_priority():
		return
	
	if allow_panning:
		var pan: Vector2 = Vector2.ZERO
		pan.x = Input.get_axis(&"editor_pan_left", &"editor_pan_right")
		pan.y = Input.get_axis(&"editor_pan_up", &"editor_pan_down")
		camera_position += (pan * LINEAR_PAN_SPEED) / camera_zoom
		viewport_moved.emit(camera_position, camera_zoom)
		if Input.is_action_just_pressed(&"editor_zoom_in"): 
			refocus_camera(Vector2.INF, camera_zoom * 2, false)
		if Input.is_action_just_pressed(&"editor_zoom_out"): 
			refocus_camera(Vector2.INF, camera_zoom * 0.5, false)


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			# Mouse pan active/deactivate
			MOUSE_BUTTON_MIDDLE when event.is_pressed():
				is_mouse_panning = true
			MOUSE_BUTTON_MIDDLE when event.is_released():
				is_mouse_panning = false
			
			# Mouse zooming
			MOUSE_BUTTON_WHEEL_UP when allow_zooming:
				_zoom_at(get_root().get_global_mouse_position(), 0.1)
			MOUSE_BUTTON_WHEEL_DOWN when allow_zooming:
				_zoom_at(get_root().get_global_mouse_position(), -0.1)
	
	# Mouse panning
	if event is InputEventMouseMotion:
		if is_mouse_panning and allow_panning: 
			camera_position -= (event.relative / camera_zoom)
			viewport_moved.emit(camera_position, camera_zoom)
	
	# Screen panning
	if event is InputEventPanGesture and allow_panning:
		camera_position += (event.delta / camera_zoom) * 5
		viewport_moved.emit(camera_position, camera_zoom)
	
	# Magnify Zoom
	if event is InputEventMagnifyGesture and allow_zooming:
		_zoom_at(_root.get_global_mouse_position(), (event.factor - 1) * (camera_zoom.x / 4))
	
	# Reset to origin
	if event is InputEventKey:
		# TODO: Replace with input action
		if event.keycode == KEY_0 and event.is_pressed():
			refocus_camera(Vector2(0, 0), Vector2.ONE)


func get_root() -> Node2D:
	return _root


func add_object(object: GameObject, pos: Vector2i = Vector2i.ZERO, layer_id: String = "a0r0") -> void:
	var layer: LDLayer = get_or_create_layer(layer_id)
	
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = object.ld_preview_texture
	layer.add_child(sprite)
	sprite.position = pos


func get_or_create_layer(layer_id: String) -> LDLayer:
	var normalized: String = LDLayer.normalize_id(layer_id)
	var parsed: Dictionary = LDLayer.parse_id(normalized)
	var abs_id: String = "a%d" % parsed.absolute_index
	
	var abs_layer: LDLayer = _get_or_create_abs_layer(abs_id, parsed.absolute_index)
	
	for child: Node in abs_layer.get_children():
		if child is LDLayer and (child as LDLayer).layer_id == normalized:
			return child as LDLayer
	
	var rel_layer: LDLayer = LDLayer.new()
	rel_layer.name = "r%d" % parsed.relative_index
	rel_layer.layer_id = normalized
	rel_layer.absolute_index = parsed.absolute_index
	rel_layer.relative_index = parsed.relative_index
	rel_layer.decoration_layer = parsed.absolute_index != 0
	abs_layer.add_child(rel_layer)
	_sort_rel_layers(abs_layer)
	return rel_layer


func refocus_camera(pos: Vector2 = Vector2.INF, zoom: Vector2 = Vector2.INF, enforce_finish: bool = true) -> void:
	if is_refocusing and enforce_finish:
		return
	
	is_refocusing = true
	
	var tween: Tween = create_tween().set_parallel()
	tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	if pos != Vector2.INF:
		allow_panning = false
		tween.tween_property(self, ^"camera_position", pos, 0.5)
	if zoom != Vector2.INF:
		allow_zooming = false
		tween.tween_property(self, ^"camera_zoom", zoom, 0.5)
	tween.tween_method(func(_t: float) -> void:
		_on_viewport_moved(camera_position, camera_zoom)
		, 0.0, 1.0, 0.5
	)
	
	await tween.finished
	allow_panning = true
	allow_zooming = true
	is_refocusing = false
	viewport_moved.emit(camera_position, camera_zoom)


func _get_or_create_abs_layer(abs_id: String, absolute_index: int) -> LDLayer:
	for child: Node in _layers_root.get_children():
		if child is LDLayer and (child as LDLayer).name == abs_id:
			return child as LDLayer
	
	var abs_layer: LDLayer = LDLayer.new()
	abs_layer.name = abs_id
	abs_layer.layer_id = abs_id
	abs_layer.absolute_index = absolute_index
	abs_layer.relative_index = 0
	abs_layer.decoration_layer = absolute_index != 0
	_layers_root.add_child(abs_layer)
	_sort_layers()
	return abs_layer


func _sort_rel_layers(abs_layer: LDLayer) -> void:
	var layers: Array[Node] = abs_layer.get_children()
	layers.sort_custom(func(a: Node, b: Node) -> bool:
		var la: LDLayer = a as LDLayer
		var lb: LDLayer = b as LDLayer
		if not la or not lb:
			return false
		return la.relative_index < lb.relative_index
	)
	for i: int in layers.size():
		abs_layer.move_child(layers[i], i)


func _sort_layers() -> void:
	var layers: Array[Node] = _layers_root.get_children()
	layers.sort_custom(func(a: Node, b: Node) -> bool:
		var la: LDLayer = a as LDLayer
		var lb: LDLayer = b as LDLayer
		if not la or not lb:
			return false
		if la.absolute_index != lb.absolute_index:
			return la.absolute_index < lb.absolute_index
		return la.relative_index < lb.relative_index
	)
	for i: int in layers.size():
		_layers_root.move_child(layers[i], i)


func _on_viewport_moved(pos: Vector2 = camera_position, zoom: Vector2 = camera_zoom) -> void:
	var mat: ShaderMaterial = _viewport_bg.material as ShaderMaterial
	if not mat:
		return
	mat.set_shader_parameter("camera_position", pos)
	mat.set_shader_parameter("camera_zoom", zoom)
	mat.set_shader_parameter("screen_size", get_viewport().get_visible_rect().size)


func _zoom_at(pos: Vector2, zoom_delta: float) -> void:
	var old_zoom: Vector2 = camera_zoom
	camera_zoom = (old_zoom + Vector2(zoom_delta, zoom_delta)).clamp(Vector2(0.1, 0.1), Vector2(10.0, 10.0))
	camera_position += (pos - camera_position) * (1.0 - old_zoom.x / camera_zoom.x)
	viewport_moved.emit(camera_position, camera_zoom)
