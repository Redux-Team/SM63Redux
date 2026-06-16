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
@export var _viewport_grid: ColorRect
@export var _root: LDViewportRoot
@export var _selection_overlay: LDSelectionOverlay
@export var _touch_indicator: LDTouchSwipeIndicator
@export var _background_root: Control
@export var _global_anchor: LDViewportGlobalAnchor
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
			_viewport_input.mouse_default_cursor_shape = Control.CURSOR_MOVE
		else:
			var tool: LDTool = LD.get_tool_handler().get_selected_tool()
			if tool:
				tool.set_cursor_shape(tool.get_cursor_shape())
			else:
				_viewport_input.mouse_default_cursor_shape = Control.CURSOR_ARROW

var _bound_area: LDArea
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
	
	LDLevel._inst.active_area_changed.connect(_bind_area)
	_bind_area(LDLevel.get_active_area())


## Tracks the active area's layer signals, rebinding when the active area changes so the viewport
## follows whichever area is being edited.
func _bind_area(area: LDArea) -> void:
	_bound_area = area
	if not area.layer_created.is_connected(_on_layer_created):
		area.layer_created.connect(_on_layer_created)
	if not area.active_layer_changed.is_connected(_on_active_layer_changed):
		area.active_layer_changed.connect(_on_active_layer_changed)
	area.refresh_layer_visuals()


func _process(delta: float) -> void:
	if not has_input_priority():
		return
	
	if allow_panning:
		var pan: Vector2 = Vector2.ZERO
		pan.x = Input.get_axis(&"editor_pan_left", &"editor_pan_right")
		pan.y = Input.get_axis(&"editor_pan_up", &"editor_pan_down")
		if not (Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_ALT)):
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
	
	if not Singleton.get_input_handler().is_using_touch():
		if event is InputEventMouseButton:
			match event.button_index:
				MOUSE_BUTTON_MIDDLE when event.is_pressed():
					is_mouse_panning = true
				MOUSE_BUTTON_MIDDLE when event.is_released():
					is_mouse_panning = false
				MOUSE_BUTTON_WHEEL_UP when allow_zooming:
					_zoom_at(_root.get_global_mouse_position(), 0.1)
				MOUSE_BUTTON_WHEEL_DOWN when allow_zooming:
					_zoom_at(_root.get_global_mouse_position(), -0.1)
		
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
	
	if Singleton.get_input_handler().is_using_touch():
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
				var current_distance: float = (points.get(0) as Vector2).distance_to(points.get(1) as Vector2)
				
				if _last_pinch_distance > 0.0 and allow_zooming:
					var zoom_delta: float = (current_distance - _last_pinch_distance) * 0.005
					var center_screen: Vector2 = ((points.get(0) as Vector2) + (points.get(1) as Vector2)) * 0.5
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


## Returns the world-space root node used for mouse position and coordinate transforms.
func get_root() -> LDViewportRoot:
	return _root


## Returns the background root node.
func get_background_root() -> Control:
	return _background_root


## Returns the selection overlay node.
func get_selection_overlay() -> LDSelectionOverlay:
	return _selection_overlay


## Returns the global anchor for the viewport. Useful tool for having nodes be positioned
## with a consistent size no matter the zoom.
func get_global_anchor() -> LDViewportGlobalAnchor:
	return _global_anchor


## Returns the currently selected objects.
func get_selected_objects() -> Array[LDObject]:
	return _selected_objects


## Sets the selected objects, filtering out non-selectable ones and updating their visual state.
func set_selected_objects(objects: Array[LDObject]) -> void:
	for obj: LDObject in _selected_objects:
		if obj and not obj.is_queued_for_deletion():
			obj.set_selection_state(LDObject.SelectionState.HIDDEN)
	
	_selected_objects = objects.filter(func(o: LDObject) -> bool:
		var game_object: GameObject = GameDB.get_db().find_game_object(o.source_object_id)
		return game_object.ld_flags & (1 << GameObject.LD_SELECTABLE)
	)
	
	for obj: LDObject in _selected_objects:
		obj.set_selection_state(LDObject.SelectionState.SELECTED)
	
	selection_changed.emit(_selected_objects)


## Clears the current selection.
func clear_selection() -> void:
	set_selected_objects([])


## Switches the active layer to `target_index`. With "Follow" on, every selected layerable object
## is shifted by the same delta as the active layer (creating layers at the ends as needed), so the
## selection travels relative to where you move.
func navigate_active_layer(target_index: int) -> void:
	var area: LDArea = LDLevel.get_active_area()
	var delta: int = target_index - area.get_active_layer_index()
	var following: Array[LDObject] = []
	if delta != 0 and LD.get_ui().get_viewport_handler().is_follow_enabled():
		following = get_selected_objects().duplicate()

	area.set_active_layer(target_index)

	for obj: LDObject in following:
		if not is_instance_valid(obj):
			continue
		var game_object: GameObject = GameDB.get_db().find_game_object(obj.source_object_id)
		if not game_object or not (game_object.ld_flags & (1 << GameObject.LD_LAYERABLE)):
			continue
		area.move_object_to_layer(obj, obj.get_layer_index() + delta)

	if not following.is_empty():
		area.refresh_layer_visuals()


## Returns whether the viewport is currently in a panning state.
func is_panning() -> bool:
	return is_mouse_panning or _touch_mode == 1


## Converts a world-space rect to screen-space coordinates.
func world_rect_to_screen(world_top_left: Vector2, world_size: Vector2) -> Rect2:
	var full_transform: Transform2D = get_viewport().get_canvas_transform() * _root.get_global_transform()
	var screen_top_left: Vector2 = full_transform * world_top_left
	var screen_bottom_right: Vector2 = full_transform * (world_top_left + world_size)
	return Rect2(screen_top_left, screen_bottom_right - screen_top_left).abs()


## Refreshes the viewport by slightly moving the camera and emitting a move signal
func refresh() -> void:
	viewport_moved.emit(camera_position, camera_zoom)
	camera.position.x += 0.01


## Smoothly moves the camera to the given position and/or zoom level.
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


static func get_instance() -> LDViewport:
	return _inst


func _on_layer_created(_layer: LDLayer) -> void:
	LDLevel.get_active_area().refresh_layer_visuals()


func _on_active_layer_changed(_index: int) -> void:
	LDLevel.get_active_area().refresh_layer_visuals()


func _on_viewport_moved(pos: Vector2 = camera_position, zoom: Vector2 = camera_zoom) -> void:
	var mat: ShaderMaterial = _viewport_grid.material as ShaderMaterial
	if not mat:
		return
	
	mat.set_shader_parameter("camera_position", pos)
	mat.set_shader_parameter("camera_zoom", zoom)
	mat.set_shader_parameter("screen_size", get_viewport().get_visible_rect().size)
	
	get_global_anchor().refresh()


func _zoom_at(pos: Vector2, zoom_delta: float) -> void:
	var old_zoom: Vector2 = camera_zoom
	camera_zoom = (old_zoom + Vector2(zoom_delta, zoom_delta)).clamp(CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
	camera_position += (pos - camera_position) * (1.0 - old_zoom.x / camera_zoom.x)
	viewport_moved.emit(camera_position, camera_zoom)
