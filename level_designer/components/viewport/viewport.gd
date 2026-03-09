class_name LDViewport
extends Node2D


## Emits when the viewport is moved and/or zoomed.
signal viewport_moved(pos: Vector2, zoom: Vector2)


@export var camera: Camera2D
@export_group("Internal")
@export var _layers_root: Node2D
@export var _viewport_bg: ColorRect


var mouse_panning: bool = false:
	set(mp):
		Input.set_default_cursor_shape(Input.CURSOR_MOVE if mp else Input.CURSOR_ARROW)
		mouse_panning = mp


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_moved)
	viewport_moved.connect(_on_viewport_moved)
	_on_viewport_moved(camera.position, camera.zoom)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			# Mouse pan active/deactivate
			MOUSE_BUTTON_MIDDLE when event.is_pressed():
				mouse_panning = true
			MOUSE_BUTTON_MIDDLE when event.is_released():
				mouse_panning = false
			
			# Mouse zooming
			MOUSE_BUTTON_WHEEL_UP:
				_zoom_at(get_global_mouse_position(), 0.1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at(get_global_mouse_position(), -0.1)
	
	# Mouse panning
	if event is InputEventMouseMotion:
		if mouse_panning:
			camera.position -= (event.relative / camera.zoom)
			viewport_moved.emit(camera.position, camera.zoom)


func add_object(object: Node2D, pos: Vector2i = Vector2i.ZERO, layer_id: String = "a0r0") -> void:
	var layer: LDLayer = get_or_create_layer(layer_id)
	layer.add_child(object)
	object.position = pos


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


func _on_viewport_moved(pos: Vector2 = camera.position, zoom: Vector2 = camera.zoom) -> void:
	var mat: ShaderMaterial = _viewport_bg.material as ShaderMaterial
	if not mat:
		return
	mat.set_shader_parameter("camera_position", pos)
	mat.set_shader_parameter("camera_zoom", zoom)
	mat.set_shader_parameter("screen_size", get_viewport().get_visible_rect().size)


func _zoom_at(pos: Vector2, zoom_delta: float) -> void:
	var old_zoom: Vector2 = camera.zoom
	camera.zoom = (old_zoom + Vector2(zoom_delta, zoom_delta)).clamp(Vector2(0.1, 0.1), Vector2(10.0, 10.0))
	camera.position += (pos - camera.position) * (1.0 - old_zoom.x / camera.zoom.x)
	viewport_moved.emit(camera.position, camera.zoom)
