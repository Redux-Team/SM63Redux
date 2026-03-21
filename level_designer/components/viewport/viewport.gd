@warning_ignore_start("unused_signal")
class_name LDViewport
extends LDComponent


const SNAPPING_SIZE: int = 4
const HOLD_THRESHOLD_SEC: float = 0.75
const MOVE_THRESHOLD: float = 8.0
const SWIPE_DISMISS_THRESHOLD: float = 6.0


signal viewport_moved(pos: Vector2, zoom: Vector2)
signal viewport_input(event: InputEvent)
signal selection_changed(objects: Array[LDObject])
signal object_hovered(object: LDObject)
signal object_unhovered(object: LDObject)
signal touch_tap(pos: Vector2)
signal touch_swipe_began(pos: Vector2)
signal touch_swipe_moved(pos: Vector2)
signal touch_swipe_ended

const LINEAR_PAN_SPEED: float = 10.0
const CAMERA_ZOOM_MIN: Vector2 = Vector2(0.05, 0.05)
const CAMERA_ZOOM_MAX: Vector2 = Vector2(4.0, 4.0)

static var _inst: LDViewport

@export var camera: Camera2D
@export_group("Internal")
@export var _layers_root: Node2D
@export var _viewport_bg: ColorRect
@export var _root: LDViewportRoot
@export var _selection_overlay: LDSelectionOverlay
@export var _touch_indicator: LDTouchSwipeIndicator
@warning_ignore("unused_private_class_variable") @export var _viewport_input: Control


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
		is_mouse_panning = mp
		if mp:
			Input.set_default_cursor_shape(Input.CURSOR_MOVE)
		else:
			var tool: LDTool = LD.get_tool_handler().get_selected_tool()
			if tool:
				tool.set_cursor_shape(tool.get_cursor_shape())
			else:
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)

var _selected_objects: Array[LDObject] = []

var _touch_points: Dictionary[int, Vector2] = {}
var _hold_timer: float = 0.0
var _touch_start_pos: Vector2
var _touch_moved: bool = false
var _touch_mode: int = 0
var _last_pinch_distance: float = 0.0


func _on_ready() -> void:
	_inst = self
	get_viewport().size_changed.connect(_on_viewport_moved)
	viewport_moved.connect(_on_viewport_moved)
	_on_viewport_moved(camera_position, camera_zoom)
	set_input_priority()


func _process(delta: float) -> void:
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
	
	if _touch_mode == 0 and _touch_points.size() == 1:
		_hold_timer += delta
		if _touch_indicator and not _touch_moved:
			var progress: float = clampf(_hold_timer / HOLD_THRESHOLD_SEC, 0.0, 1.0)
			_touch_indicator.set_progress(progress)
		if _hold_timer >= HOLD_THRESHOLD_SEC and not _touch_moved:
			_touch_mode = 2
			touch_swipe_began.emit(_touch_start_pos)


func _input(event: InputEvent) -> void:
	if event is InputEventMagnifyGesture:
		LD.get_input_handler().dispatch(event)


func _on_viewport_input(event: InputEvent) -> void:
	viewport_input.emit(event)
	
	if Singleton.current_input_device != Singleton.InputType.TOUCHSCREEN:
		if event is InputEventMouseButton:
			match event.button_index:
				MOUSE_BUTTON_MIDDLE when event.is_pressed():
					is_mouse_panning = true
				MOUSE_BUTTON_MIDDLE when event.is_released():
					is_mouse_panning = false
				MOUSE_BUTTON_WHEEL_UP when allow_zooming:
					_zoom_at(get_root().get_global_mouse_position(), 0.1)
				MOUSE_BUTTON_WHEEL_DOWN when allow_zooming:
					_zoom_at(get_root().get_global_mouse_position(), -0.1)
		
		if event is InputEventMouseMotion:
			if is_mouse_panning and allow_panning:
				camera_position -= (event.relative / camera_zoom)
				viewport_moved.emit(camera_position, camera_zoom)
		
		if event is InputEventPanGesture and allow_panning:
			camera_position += (event.delta / camera_zoom) * 5
			viewport_moved.emit(camera_position, camera_zoom)
	
	if event is InputEventMagnifyGesture and allow_zooming:
		_zoom_at(_root.get_global_mouse_position(), (event.factor - 1) * (camera_zoom.x / 4))
	
	if event is InputEventKey:
		if event.keycode == KEY_0 and event.is_pressed():
			refocus_camera(Vector2(0, 0), Vector2.ONE)
		if event.is_pressed() and not event.echo:
			match event.keycode:
				KEY_B:
					LD.get_tool_handler().select_tool("brush")
				KEY_Q:
					LD.get_tool_handler().select_tool("select")
	
	if Singleton.current_input_device == Singleton.InputType.TOUCHSCREEN:
		if event is InputEventScreenTouch:
			if event.pressed:
				_touch_points[event.index] = event.position
				if _touch_points.size() == 1:
					_touch_start_pos = event.position
					_touch_moved = false
					_hold_timer = 0.0
					_touch_mode = 0
					if _touch_indicator:
						_touch_indicator.show_at(event.position)
			else:
				if _touch_points.size() == 1:
					if _touch_mode == 0 and not _touch_moved:
						touch_tap.emit(event.position)
						if _touch_indicator:
							_touch_indicator.dismiss()
					elif _touch_mode == 2:
						touch_swipe_ended.emit()
						if _touch_indicator:
							_touch_indicator.dismiss()
				_touch_points.erase(event.index)
				if _touch_points.is_empty():
					_touch_mode = 0
					_hold_timer = 0.0
					_last_pinch_distance = 0.0
					if _touch_indicator:
						_touch_indicator.dismiss()

		if event is InputEventScreenDrag:
			_touch_points[event.index] = event.position
			
			if _touch_points.size() == 2:
				if _touch_indicator:
					_touch_indicator.dismiss()
				_touch_mode = 1
				var points: Array = _touch_points.values()
				var current_distance: float = (points[0] as Vector2).distance_to(points[1] as Vector2)
				
				if _last_pinch_distance > 0.0 and allow_zooming:
					var zoom_delta: float = (current_distance - _last_pinch_distance) * 0.005
					var center_screen: Vector2 = ((points[0] as Vector2) + (points[1] as Vector2)) * 0.5
					var full_transform: Transform2D = get_viewport().get_canvas_transform() * _root.get_global_transform()
					var center_world: Vector2 = full_transform.affine_inverse() * center_screen
					_zoom_at(center_world, zoom_delta)
				
				_last_pinch_distance = current_distance
				
				if allow_panning:
					camera_position -= (event.relative / camera_zoom)
					viewport_moved.emit(camera_position, camera_zoom)
				return
			
			_last_pinch_distance = 0.0
			
			if _touch_mode == 0:
				if _touch_indicator:
					_touch_indicator.dismiss()
				var dist: float = event.position.distance_to(_touch_start_pos)
				if dist > MOVE_THRESHOLD:
					_touch_moved = true
					_touch_mode = 1
			
			if _touch_mode == 1 and allow_panning:
				camera_position -= (event.relative / camera_zoom)
				viewport_moved.emit(camera_position, camera_zoom)
			elif _touch_mode == 2:
				var swipe_dist: float = event.position.distance_to(_touch_start_pos)
				if _touch_indicator and swipe_dist > SWIPE_DISMISS_THRESHOLD:
					_touch_indicator.dismiss()
				touch_swipe_moved.emit(event.position)


func get_root() -> LDViewportRoot:
	return _root


func get_selection_overlay() -> LDSelectionOverlay:
	return _selection_overlay


func get_selected_objects() -> Array[LDObject]:
	return _selected_objects


func set_selected_objects(objects: Array[LDObject]) -> void:
	for obj: LDObject in _selected_objects:
		if obj and not obj.is_queued_for_deletion():
			obj.set_selection_state(LDObject.SelectionState.HIDDEN)
	
	_selected_objects = objects
	
	for obj: LDObject in _selected_objects:
		obj.set_selection_state(LDObject.SelectionState.SELECTED)
	
	selection_changed.emit(_selected_objects)


func clear_selection() -> void:
	set_selected_objects([])


func get_all_objects() -> Array[LDObject]:
	var result: Array[LDObject] = []
	for abs_layer: Node in _layers_root.get_children():
		for rel_layer: Node in abs_layer.get_children():
			for child: Node in rel_layer.get_children():
				var obj: LDObject = child as LDObject
				if obj:
					result.append(obj)
	return result


func world_rect_to_screen(world_top_left: Vector2, world_size: Vector2) -> Rect2:
	var full_transform: Transform2D = get_viewport().get_canvas_transform() * _root.get_global_transform()
	var screen_top_left: Vector2 = full_transform * world_top_left
	var screen_bottom_right: Vector2 = full_transform * (world_top_left + world_size)
	return Rect2(screen_top_left, screen_bottom_right - screen_top_left).abs()


func add_object(object: LDObject, pos: Vector2i = Vector2i.ZERO, layer_id: String = "a0r0") -> void:
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


func is_panning() -> bool:
	return is_mouse_panning or _touch_mode == 1


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


static func _get_instance() -> LDViewport:
	return _inst


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
