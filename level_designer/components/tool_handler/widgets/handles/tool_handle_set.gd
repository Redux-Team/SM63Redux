class_name LDToolHandleSet
extends Control

## Pool of [LDToolHandle] scene instances. Composed into a widget scene rather than inherited,
## because a widget may own several sets with different styles - the polygon widget's outer
## vertices, its hole vertices and its single edge preview are three sets over one object.
##
## The pool only ever grows: a topology change hides the surplus instead of freeing it, so
## dragging a vertex across a polygon no longer churns a node per point per frame.

## Fallback so a set whose style failed to load still shows something. A handle sized from a null
## style used to collapse to nothing, which reads as "the tool is broken" rather than "the art is
## missing".
const FALLBACK_SIZE: Vector2 = Vector2(12.0, 12.0)


@export var handle_scene: PackedScene
@export var style: LDToolWidgetStyle
## How the pool sizes its handles against the camera.
@export var render_space: LDToolWidgetStyle.RenderSpace = LDToolWidgetStyle.RenderSpace.GLOBAL


var _handles: Array[LDToolHandle] = []
var _used: int = 0


## Reserves [param count] handles, growing the pool as needed and hiding the rest. Returns the
## live slice so callers can place each one.
func resize_to(count: int) -> Array[LDToolHandle]:
	while _handles.size() < count:
		var handle: LDToolHandle = handle_scene.instantiate()
		handle.style = style
		add_child(handle)
		_handles.append(handle)
	
	for i: int in _handles.size():
		var handle: LDToolHandle = _handles.get(i)
		handle.visible = i < count
		if i >= count:
			handle.state = LDToolWidgetStyle.State.NORMAL
			handle.shade = Color.WHITE
	
	_used = count
	return _handles.slice(0, count)


func get_handle(index: int) -> LDToolHandle:
	if index < 0 or index >= _used:
		return null
	return _handles.get(index)


func get_used_count() -> int:
	return _used


## Centres handle [param index] on a screen point, sized for the pool's render space.
func place(index: int, screen_pos: Vector2, zoom: float) -> void:
	var handle: LDToolHandle = get_handle(index)
	if handle:
		handle.place(screen_pos, screen_size(zoom, handle.style))


## The screen size a handle draws at under the current camera zoom. [param override] lets a handle
## wearing its own style size itself by that style rather than by the pool's.
func screen_size(zoom: float, override: LDToolWidgetStyle = null) -> Vector2:
	var handle_style: LDToolWidgetStyle = override if override else style
	if not handle_style:
		return FALLBACK_SIZE
	match render_space:
		LDToolWidgetStyle.RenderSpace.LOCAL:
			return handle_style.size * zoom
		LDToolWidgetStyle.RenderSpace.LOCAL_CLAMPED:
			return (handle_style.size * zoom).clamp(handle_style.min_screen_size, handle_style.max_screen_size)
	return handle_style.size


## Index of the handle whose grab radius covers [param screen_pos], nearest first, or -1.
func find_at(screen_pos: Vector2) -> int:
	var best: int = -1
	var best_distance: float = INF
	for i: int in _used:
		var handle: LDToolHandle = _handles.get(i)
		if not handle.visible:
			continue
		var distance: float = screen_pos.distance_to(handle.screen_center)
		if distance <= handle.get_grab_radius() and distance < best_distance:
			best_distance = distance
			best = i
	return best


## Marks one handle hovered and/or pressed and clears the state of every other handle.
func set_active(hovered: int, pressed: int = -1) -> void:
	for i: int in _used:
		var is_hovered: bool = i == hovered
		var is_pressed: bool = i == pressed
		var state: LDToolWidgetStyle.State = LDToolWidgetStyle.State.NORMAL
		if is_hovered and is_pressed:
			state = LDToolWidgetStyle.State.HOVER_PRESSED
		elif is_pressed:
			state = LDToolWidgetStyle.State.PRESSED
		elif is_hovered:
			state = LDToolWidgetStyle.State.HOVER
		_handles.get(i).state = state


func set_shade(index: int, shade: Color) -> void:
	var handle: LDToolHandle = get_handle(index)
	if handle:
		handle.shade = shade


func clear() -> void:
	resize_to(0)
