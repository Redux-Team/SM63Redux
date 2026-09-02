@warning_ignore_start("unused_private_class_variable", "unused_parameter")
@abstract class_name LDTool
extends Node


var viewport: LDViewport:
	get:
		return LD.get_editor_viewport()

var _enabled: bool = false
var _preview_object: LDObject

## Transforms resolved once per hit-test pass rather than per object. A pass runs over every object
## in the level on every mouse event, so reading the canvas transform and walking up to a layer's
## object root for each one dominated what the tests themselves cost.
var _hit_canvas_xform: Transform2D = Transform2D.IDENTITY
var _hit_canvas_valid: bool = false
var _hit_parent: Node2D = null
var _hit_parent_xform: Transform2D = Transform2D.IDENTITY
## Scratch buffer for screen-space shape corners, reused across objects so a pass allocates nothing.
var _hit_points: PackedVector2Array = PackedVector2Array()


@abstract func get_tool_name() -> String
@abstract func _on_ready() -> void


func _ready() -> void:
	LD.get_editor_viewport().viewport_input.connect(_on_viewport_input)
	if wants_overlay():
		LD.get_editor_viewport().viewport_moved.connect(_on_overlay_viewport_moved)
		LD.get_editor_viewport().selection_changed.connect(_on_overlay_selection_changed)
	_on_ready()


func _on_enable() -> void:
	viewport.set_cursor_shape(get_cursor_shape())
	if wants_overlay():
		viewport.get_selection_overlay().queue_redraw()


func _on_disable() -> void:
	viewport.set_cursor_shape(Control.CURSOR_ARROW)
	if wants_overlay():
		viewport.get_selection_overlay().queue_redraw()
	_destroy_preview()


func wants_overlay() -> bool:
	return false


## Whether this tool can already place the given object. Picking an object in the browser hands off
## to whichever tool [method GameObject.get_placement_tool] names, and this is how a tool offering
## a second way to build the same thing - the tile tool against terrain - says it does not need to
## be handed off from.
func can_place(_obj: GameObject) -> bool:
	return false


func get_cursor_shape() -> Control.CursorShape:
	return Control.CURSOR_ARROW


func set_cursor_shape(cursor_shape: Control.CursorShape) -> void:
	viewport.set_cursor_shape(cursor_shape)


func draw_overlay(_draw_node: CanvasItem) -> void:
	pass


func _on_viewport_input(_event: InputEvent) -> void:
	pass


func _on_overlay_viewport_moved(_pos: Vector2, _zoom: Vector2) -> void:
	if is_active():
		viewport.get_selection_overlay().queue_redraw()


func _on_overlay_selection_changed(_objects: Array[LDObject]) -> void:
	if is_active():
		viewport.get_selection_overlay().queue_redraw()


#region Hit testing
## Starts a hit-test pass, dropping what the previous one cached. Call once before testing a batch
## of objects; the transforms below are only valid for the length of a pass.
func begin_hit_pass() -> void:
	_hit_canvas_valid = false
	_hit_parent = null


## The viewport's canvas transform for this pass.
func hit_canvas_xform() -> Transform2D:
	if not _hit_canvas_valid:
		_hit_canvas_xform = viewport.get_viewport().get_canvas_transform()
		_hit_canvas_valid = true
	return _hit_canvas_xform


## World-to-screen transform for one object, built from its layer's object root. Objects arrive
## grouped by layer, so remembering the last root turns a global-transform walk per object into one
## per layer.
func object_screen_xform(obj: LDObject) -> Transform2D:
	var parent: Node2D = obj.get_parent() as Node2D
	if not parent:
		return hit_canvas_xform() * obj.get_global_transform()
	if parent != _hit_parent:
		_hit_parent = parent
		_hit_parent_xform = hit_canvas_xform() * parent.get_global_transform()
	return _hit_parent_xform * obj.transform


## Screen-space bounds of an object, from its cached local bounds. Four transforms regardless of how
## many points the object has, so it is cheap enough to run against every object every frame. An
## empty rect means the object offers no cheap bounds and callers should skip the reject.
func object_screen_rect(obj: LDObject) -> Rect2:
	var bounds: Rect2 = obj.get_local_bounds()
	if bounds.size == Vector2.ZERO:
		return Rect2()
	var xform: Transform2D = object_screen_xform(obj)
	# An unrotated object keeps its bounds axis aligned, so two opposite corners describe them.
	if is_zero_approx(xform.x.y) and is_zero_approx(xform.y.x):
		var min_corner: Vector2 = xform * bounds.position
		var max_corner: Vector2 = xform * bounds.end
		return Rect2(min_corner, max_corner - min_corner).abs()
	var rect: Rect2 = Rect2(xform * bounds.position, Vector2.ZERO)
	rect = rect.expand(xform * (bounds.position + Vector2(bounds.size.x, 0.0)))
	rect = rect.expand(xform * bounds.end)
	rect = rect.expand(xform * (bounds.position + Vector2(0.0, bounds.size.y)))
	return rect


## Whether any of an object's rectangular editor shapes covers a screen point. Returns false when
## the object has no such shapes, which the caller is expected to handle its own way.
func object_shapes_have_point(obj: LDObject, point: Vector2) -> bool:
	var local_points: PackedVector2Array = obj.get_shape_points()
	if local_points.is_empty():
		return false
	var xform: Transform2D = object_screen_xform(obj)
	# Placed objects are hardly ever rotated, and an unrotated rectangle stays axis aligned, so the
	# test collapses to a rect against two transformed corners.
	if is_zero_approx(xform.x.y) and is_zero_approx(xform.y.x):
		for offset: int in range(0, local_points.size(), 4):
			var a: Vector2 = xform * local_points[offset]
			var b: Vector2 = xform * local_points[offset + 2]
			if Rect2(a, b - a).abs().has_point(point):
				return true
		return false
	_hit_points.resize(local_points.size())
	for i: int in local_points.size():
		_hit_points[i] = xform * local_points[i]
	for offset: int in range(0, _hit_points.size(), 4):
		if quad_has_point(_hit_points, offset, point):
			return true
	return false


## Separating-axis test between a screen-space box and the convex quad at `offset` in `points`.
## Exact for the rotated rectangles the editor shapes are, and allocation free, which matters
## because a box drag runs it against every object on every mouse motion.
static func quad_intersects_rect(points: PackedVector2Array, offset: int, rect: Rect2) -> bool:
	var min_x: float = points[offset].x
	var max_x: float = min_x
	var min_y: float = points[offset].y
	var max_y: float = min_y
	for i: int in range(offset + 1, offset + 4):
		min_x = minf(min_x, points[i].x)
		max_x = maxf(max_x, points[i].x)
		min_y = minf(min_y, points[i].y)
		max_y = maxf(max_y, points[i].y)
	
	var rect_end: Vector2 = rect.end
	if max_x < rect.position.x or min_x > rect_end.x or max_y < rect.position.y or min_y > rect_end.y:
		return false
	
	# The box's own two axes are the test above; these are the quad's.
	for i: int in 2:
		var a: Vector2 = points[offset + i]
		var b: Vector2 = points[offset + i + 1]
		var axis: Vector2 = Vector2(a.y - b.y, b.x - a.x)
		var quad_min: float = INF
		var quad_max: float = -INF
		for j: int in 4:
			var d: float = axis.dot(points[offset + j])
			quad_min = minf(quad_min, d)
			quad_max = maxf(quad_max, d)
		var box_min: float = axis.x * (rect.position.x if axis.x > 0.0 else rect_end.x) \
			+ axis.y * (rect.position.y if axis.y > 0.0 else rect_end.y)
		var box_max: float = axis.x * (rect_end.x if axis.x > 0.0 else rect.position.x) \
			+ axis.y * (rect_end.y if axis.y > 0.0 else rect.position.y)
		if quad_max < box_min or quad_min > box_max:
			return false
	
	return true


## Whether a point falls inside the convex quad at `offset` in `points`. Boundary hits count, so a
## click on a shape's own edge still picks it.
static func quad_has_point(points: PackedVector2Array, offset: int, point: Vector2) -> bool:
	var positive: bool = false
	var negative: bool = false
	for i: int in 4:
		var a: Vector2 = points[offset + i]
		var b: Vector2 = points[offset + (i + 1) % 4]
		var cross: float = (b - a).cross(point - a)
		if cross > 0.0:
			positive = true
		elif cross < 0.0:
			negative = true
		if positive and negative:
			return false
	return positive or negative
#endregion


func get_tool_handler() -> LDToolHandler:
	return owner


func is_active() -> bool:
	return get_tool_handler().get_selected_tool() == self


func spawn_preview(obj: GameObject) -> LDObject:
	_destroy_preview()
	if not obj:
		return null
	_preview_object = obj.get_editor_instance()
	_preview_object.is_preview = true
	_preview_object.init_properties(obj)
	LD.get_area().add_object(_preview_object)
	_preview_object.bind_to_active_layer()
	return _preview_object


func get_preview() -> LDObject:
	return _preview_object if is_instance_valid(_preview_object) else null


func has_preview() -> bool:
	return is_instance_valid(_preview_object)


func release_preview() -> LDObject:
	var obj: LDObject = _preview_object
	_preview_object = null
	return obj


func _destroy_preview() -> void:
	if is_instance_valid(_preview_object):
		_preview_object.queue_free()
	_preview_object = null
