@tool
class_name RigTimelineGrid
extends Control


signal variant_edit_requested(variant: RigVariant)

enum Drag {
	NONE,
	SCRUB,
	ROW,
	CELL,
}

enum Action {
	SELECT,
	EDIT_VARIANT,
	KEY,
	CLEAR_KEY,
	CLEAR_CLIP_KEYS,
	DUPLICATE_FRAME,
	DELETE_FRAME,
	CLEAR_STRIP,
	ADD_VARIANT,
	REMOVE_VARIANT,
	TOGGLE_INTERPOLATION,
}

const ANCHORS: StringName = &"anchors"
const LAYERS: StringName = &"layers"
const LABEL_WIDTH: float = 240.0
const HEADER: float = 26.0
const SECTION_HEIGHT: float = 24.0
const ANCHOR_HEIGHT: float = 28.0
const BASE_CELL: float = 48.0
const INDENT: float = 18.0
const DRAG_THRESHOLD: float = 6.0

@export var scroll: ScrollContainer
@export var menu: PopupMenu
@export var edits: RigEdits

var rig: SpriteRig2D:
	set(r):
		rig = r
		selected = null
		_content.clear()
		refresh()
var selected: Row
var zoom: float = 1.0:
	set(z):
		zoom = clampf(z, 0.5, 3.0)
		refresh()

var _rows: Array[Row] = []
var _tops: PackedFloat32Array = []
var _collapsed: Dictionary[StringName, bool] = {}
var _expanded: Dictionary[Node, bool] = {}
var _hover: Vector2i = Vector2i(-1, -1)
var _drag: Drag = Drag.NONE
var _dragging: bool = false
var _press: Vector2 = Vector2.ZERO
var _press_cell: Vector2i = Vector2i(-1, -1)
var _target: int = -1
var _menu_row: Row
var _menu_frame: int = -1
var _content: Dictionary[Texture2D, Rect2] = {}


func _ready() -> void:
	if not is_part_of_edited_scene():
		menu.id_pressed.connect(_on_menu_id_pressed)


func _draw() -> void:
	if not is_instance_valid(rig):
		return
	
	var view: Vector2 = _view()
	var clip: StringName = rig.current_animation
	var length: int = _length()
	if rig.clips.is_empty():
		_draw_text(
				view + Vector2(LABEL_WIDTH + 12.0, HEADER + 20.0),
				"This rig has no clips yet. Add one from the menu next to the clip picker.",
				_color(&"font_color", 0.6),
		)
	for i: int in _rows.size():
		var row: Row = _rows[i]
		var band: Rect2 = Rect2(0.0, _tops[i], size.x, _row_height(i))
		if row.is_section():
			draw_rect(band, _color(&"dark_color_2", 0.6))
			continue
		if row.equals(selected):
			draw_rect(band, _color(&"accent_color", 0.1))
		var region: Rect2 = Rect2()
		if row.has_frames():
			region = _union(row.get_frames(), row.get_animation(rig))
		for frame: int in length:
			_draw_cell(row, clip, frame, _cell_rect(i, frame), region)
	
	if length > 0:
		var playhead: float = LABEL_WIDTH + rig.current_frame * _cell()
		draw_rect(Rect2(playhead, 0.0, _cell(), size.y), _color(&"accent_color", 0.1))
	if _is_cell(_hover.y, _hover.x):
		draw_rect(_cell_rect(_hover.y, _hover.x).grow(-1.0), _color(&"font_color", 0.3), false)
	_draw_drag_feedback(length)
	_draw_header(length, view)
	_draw_labels(view)
	_draw_corner(length, view)


func _gui_input(event: InputEvent) -> void:
	if not is_instance_valid(rig):
		return
	
	if event is InputEventMouseButton:
		_on_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_on_motion(event as InputEventMouseMotion)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != Vector2i(-1, -1):
		_hover = Vector2i(-1, -1)
		queue_redraw()


func _get_tooltip(at_position: Vector2) -> String:
	return _describe(_row_at(at_position.y), _frame_at(at_position.x))


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var index: int = _row_at(at_position.y)
	return (
			index >= 0
			and _frame_at(at_position.x) >= 0
			and _rows[index].has_frames()
			and _dropped_texture(data) != null
	)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var row: Row = _rows[_row_at(at_position.y)]
	var target: Object = row.variant if row.variant else row.node
	edits.drop_strip(target, row.get_frames(), row.get_animation(rig), _dropped_texture(data))


func refresh() -> void:
	_rows.clear()
	if is_instance_valid(rig):
		var anchors: Array[Row] = []
		for anchor: RigAnchor in rig.get_anchors():
			anchors.append(Row.new(Row.Kind.NODE, ANCHORS, anchor))
			if not anchor.captured.is_connected(edits.capture):
				anchor.captured.connect(edits.capture.bind(anchor))
		var layers: Array[Row] = []
		for layer: RigLayer in rig.get_layers():
			layers.append(Row.new(Row.Kind.NODE, LAYERS, layer))
			if _expanded.get(layer, false):
				for i: int in layer.variants.size():
					var variant: RigVariant = layer.variants[i]
					if variant:
						layers.append(Row.new(Row.Kind.VARIANT, LAYERS, layer, variant, i))
		_add_section(ANCHORS, anchors)
		_add_section(LAYERS, layers)
	_tops = PackedFloat32Array([HEADER])
	for row: Row in _rows:
		_tops.append(_tops[-1] + _height_of(row))
	var index: int = _rows.find_custom(func(row: Row) -> bool: return row.equals(selected))
	selected = _rows[index] if index >= 0 else null
	custom_minimum_size = Vector2(LABEL_WIDTH + _length() * _cell() + _cell(), _tops[-1] + 8.0)
	queue_redraw()


func get_selected_anchor() -> RigAnchor:
	return selected.get_anchor() if selected else null


func _add_section(section: StringName, rows: Array[Row]) -> void:
	var header: Row = Row.new(Row.Kind.SECTION, section)
	header.count = rows.filter(func(row: Row) -> bool: return row.kind == Row.Kind.NODE).size()
	_rows.append(header)
	if not _collapsed.get(section, false):
		_rows.append_array(rows)


func _height_of(row: Row) -> float:
	if row.is_section():
		return SECTION_HEIGHT
	return ANCHOR_HEIGHT if row.is_anchor() else _cell()


func _on_button(button: InputEventMouseButton) -> void:
	var mouse_button: MouseButton = button.button_index
	if mouse_button >= MOUSE_BUTTON_WHEEL_UP and mouse_button <= MOUSE_BUTTON_WHEEL_RIGHT:
		if button.ctrl_pressed and button.pressed and mouse_button <= MOUSE_BUTTON_WHEEL_DOWN:
			zoom *= 1.1 if mouse_button == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1
			accept_event()
		return
	
	accept_event()
	if not button.pressed:
		_finish_drag()
		return
	
	grab_focus()
	var index: int = _row_at(button.position.y)
	var frame: int = _frame_at(button.position.x)
	if index == -2:
		_drag = Drag.SCRUB
		_scrub(button.position.x)
		return
	if index < 0:
		return
	
	var row: Row = _rows[index]
	if row.is_section():
		_on_section_pressed(row, button)
		return
	if frame < 0 and mouse_button == MOUSE_BUTTON_LEFT and _on_label_button(row, button):
		return
	
	_select(row)
	if frame >= 0 and frame < _length():
		rig.playing = false
		rig.current_frame = frame
	if mouse_button == MOUSE_BUTTON_RIGHT:
		_open_menu(row, frame if frame < _length() else -1, button.global_position)
		return
	if button.double_click and frame < 0 and row.variant:
		variant_edit_requested.emit(row.variant)
		return
	if button.double_click and frame >= 0 and row.is_anchor():
		edits.key(row.get_anchor(), frame)
		return
	
	_drag = Drag.CELL if frame >= 0 else Drag.ROW
	_dragging = false
	_press = button.position
	_press_cell = Vector2i(frame, index)


func _on_section_pressed(row: Row, button: InputEventMouseButton) -> void:
	var x: float = button.position.x - _view().x
	if button.button_index != MOUSE_BUTTON_LEFT or x >= LABEL_WIDTH:
		return
	if x > LABEL_WIDTH - INDENT - 10.0:
		edits.add_node(row.section == ANCHORS)
		return
	
	_collapsed[row.section] = not _collapsed.get(row.section, false)
	refresh()


func _on_label_button(row: Row, button: InputEventMouseButton) -> bool:
	var x: float = button.position.x - _view().x
	var layer: RigLayer = row.get_layer()
	if _is_foldable(row) and x >= _slot(1) and x < _slot(2):
		_expanded[layer] = not _expanded.get(layer, false)
		refresh()
		return true
	if row.kind == Row.Kind.NODE and x > LABEL_WIDTH - INDENT - 8.0:
		edits.toggle_visible(row.node as CanvasItem)
		return true
	return false


func _on_motion(motion: InputEventMouseMotion) -> void:
	var hover: Vector2i = Vector2i(_frame_at(motion.position.x), _row_at(motion.position.y))
	if hover != _hover:
		_hover = hover
		queue_redraw()
	if _drag == Drag.SCRUB:
		_scrub(motion.position.x)
		return
	if _drag == Drag.NONE:
		return
	
	_dragging = _dragging or motion.position.distance_to(_press) > DRAG_THRESHOLD
	if not _dragging:
		return
	
	if _drag == Drag.ROW:
		var insert: int = _insert_at(motion.position.y)
		_target = insert if _can_move_row(_press_cell.y, insert) else -1
	else:
		_target = clampi(_frame_at(motion.position.x), 0, _length() - 1)
	queue_redraw()


func _finish_drag() -> void:
	if _dragging and _target >= 0:
		if _drag == Drag.ROW:
			_move_row(_press_cell.y, _target)
		elif _drag == Drag.CELL and _target != _press_cell.x:
			_move_frame(_rows[_press_cell.y], _press_cell.x, _target)
	_drag = Drag.NONE
	_dragging = false
	_target = -1
	queue_redraw()


func _scrub(x: float) -> void:
	if _length() == 0:
		return
	
	rig.playing = false
	rig.current_frame = clampi(int((x - LABEL_WIDTH) / _cell()), 0, _length() - 1)


func _select(row: Row) -> void:
	selected = row
	_inspect(row)
	queue_redraw()


func _inspect(row: Row) -> void:
	if row.variant:
		EditorInterface.edit_resource(row.variant)
		return
	
	var selection: EditorSelection = EditorInterface.get_selection()
	selection.clear()
	selection.add_node(row.node)


func _describe(index: int, frame: int) -> String:
	if index < 0 or frame >= _length():
		return ""
	
	var row: Row = _rows[index]
	if row.is_section():
		var kind: String = "anchor" if row.section == ANCHORS else "layer"
		return "Click + to add a %s." % kind if frame < 0 else ""
	if frame < 0:
		return _describe_label(row)
	if row.is_anchor():
		var anchor: RigAnchor = row.get_anchor()
		var key: RigKey = anchor.get_key(rig.current_animation, frame)
		if key == null:
			var held: RigKey = anchor.get_active_key(rig.current_animation, frame)
			var source: String = "key on frame %d" % (held.frame + 1) if held else "rest pose"
			return "Holds the %s. Double-click to key this frame." % source
		var pose: Array = [key.position, key.rotation_degrees, key.z_index]
		return "Position %s\nRotation %.1f\nZ %d" % pose
	
	var animation: StringName = row.get_animation(rig)
	var texture: Texture2D = _frame_texture(row, animation, frame)
	if texture == null:
		return "Drop a PNG strip to add \"%s\"" % animation
	var atlas: AtlasTexture = texture as AtlasTexture
	var origin: Texture2D = atlas.atlas if atlas else texture
	var index_in_strip: int = posmod(frame, row.get_frames().get_frame_count(animation))
	return "%s [%d]\n%s" % [animation, index_in_strip, origin.resource_path.get_file()]


func _describe_label(row: Row) -> String:
	if row.variant:
		return "Used when %s = %s.\nDouble-click to edit." % [row.variant.axis, row.variant.value]
	
	var lines: PackedStringArray = [String(row.node.name)]
	if row.is_anchor():
		var verb: String = "blend" if row.get_anchor().interpolate else "hold"
		lines.append("Keys %s between frames." % verb)
		return "\n".join(lines)
	
	var layer: RigLayer = row.get_layer()
	var resolved: StringName = layer.resolve(rig.current_animation)
	if resolved != rig.current_animation:
		lines.append("Plays \"%s\" during this clip" % resolved)
	if layer.anchor:
		lines.append("Follows %s" % layer.anchor.name)
	for axis: StringName in layer.visible_when:
		var wanted: StringName = layer.visible_when[axis]
		lines.append("Only shown when %s is %s" % [axis, "set" if wanted.is_empty() else wanted])
	return "\n".join(lines)


func _insert_at(y: float) -> int:
	var best: int = 0
	for i: int in _tops.size():
		if absf(_tops[i] - y) < absf(_tops[best] - y):
			best = i
	return best


func _can_move_row(from: int, insert: int) -> bool:
	var row: Row = _rows[from]
	if insert == from or insert == from + 1:
		return false
	
	var above: Row = _rows[insert - 1] if insert > 0 else null
	var below: Row = _rows[insert] if insert < _rows.size() else null
	if row.variant:
		return (
				(above != null and above.node == row.node)
				or (below != null and below.variant != null and below.node == row.node)
		)
	if above == null or above.section != row.section:
		return false
	var parent: Node = row.node.get_parent()
	var below_fits: bool = (
			below != null
			and below.kind == Row.Kind.NODE
			and below.section == row.section
			and below.node.get_parent() == parent
	)
	var above_fits: bool = above.node != null and above.node.get_parent() == parent
	return below_fits or (above_fits and (below == null or below.section != row.section))


func _move_row(from: int, insert: int) -> void:
	var row: Row = _rows[from]
	if row.variant:
		var before: int = 0
		for i: int in insert:
			if _rows[i].variant and _rows[i].node == row.node and i != from:
				before += 1
		edits.move_variant(row.get_layer(), row.index, before)
		return
	
	var node: Node = row.node
	var parent: Node = node.get_parent()
	var target: int = -1
	for i: int in range(insert, _rows.size()):
		if _rows[i].kind == Row.Kind.NODE and _rows[i].node.get_parent() == parent:
			target = _rows[i].node.get_index()
			break
	if target < 0:
		for i: int in range(insert - 1, -1, -1):
			if _rows[i].kind == Row.Kind.NODE and _rows[i].node.get_parent() == parent:
				target = _rows[i].node.get_index() + 1
				break
	if target > node.get_index():
		target -= 1
	edits.move_node(node, target)


func _move_frame(row: Row, from: int, to: int) -> void:
	if row.is_anchor():
		edits.move_key(row.get_anchor(), from, to)
	else:
		edits.move_frame(row.get_frames(), row.get_animation(rig), from, to)


func _open_menu(row: Row, frame: int, at: Vector2) -> void:
	_menu_row = row
	_menu_frame = frame
	menu.clear()
	if row.is_anchor():
		menu.add_item("Select Anchor", Action.SELECT)
		menu.add_check_item("Blend Between Keys", Action.TOGGLE_INTERPOLATION)
		menu.set_item_checked(menu.item_count - 1, row.get_anchor().interpolate)
		if frame >= 0:
			menu.add_separator()
			menu.add_item("Key Frame %d" % (frame + 1), Action.KEY)
			menu.add_item("Clear Key", Action.CLEAR_KEY)
			var keyed: bool = row.get_anchor().get_key(rig.current_animation, frame) != null
			menu.set_item_disabled(menu.item_count - 1, not keyed)
		menu.add_item("Clear All Keys in Clip", Action.CLEAR_CLIP_KEYS)
	else:
		var has_frame: bool = _frame_texture(row, row.get_animation(rig), frame) != null
		if row.variant:
			menu.add_item("Edit Axis and Value...", Action.EDIT_VARIANT)
			menu.add_item("Show in Inspector", Action.SELECT)
		else:
			menu.add_item("Select Layer", Action.SELECT)
		if frame >= 0:
			menu.add_separator()
			menu.add_item("Duplicate Frame", Action.DUPLICATE_FRAME)
			menu.set_item_disabled(menu.item_count - 1, not has_frame)
			menu.add_item("Delete Frame", Action.DELETE_FRAME)
			menu.set_item_disabled(menu.item_count - 1, not has_frame)
		menu.add_item("Clear \"%s\" Strip" % row.get_animation(rig), Action.CLEAR_STRIP)
		menu.add_separator()
		if row.variant:
			menu.add_item("Remove Variant", Action.REMOVE_VARIANT)
		else:
			menu.add_item("Add Variant", Action.ADD_VARIANT)
	menu.popup(Rect2i(Vector2i(at), Vector2i.ZERO))


func _on_menu_id_pressed(id: int) -> void:
	var row: Row = _menu_row
	var anchor: RigAnchor = row.get_anchor()
	var frames: SpriteFrames = row.get_frames()
	var animation: StringName = row.get_animation(rig)
	match id:
		Action.SELECT:
			_inspect(row)
		Action.EDIT_VARIANT:
			variant_edit_requested.emit(row.variant)
		Action.TOGGLE_INTERPOLATION:
			edits.toggle_interpolation(anchor)
		Action.KEY:
			edits.key(anchor, _menu_frame)
		Action.CLEAR_KEY:
			edits.clear_key(anchor, _menu_frame)
		Action.CLEAR_CLIP_KEYS:
			edits.clear_clip_keys(anchor)
		Action.DUPLICATE_FRAME, Action.DELETE_FRAME:
			edits.edit_frame(frames, animation, _menu_frame, id == Action.DUPLICATE_FRAME)
		Action.CLEAR_STRIP:
			edits.clear_strip(frames, animation)
		Action.ADD_VARIANT:
			var variant: RigVariant = edits.add_variant(row.get_layer())
			_expanded[row.node] = true
			variant_edit_requested.emit(variant)
		Action.REMOVE_VARIANT:
			edits.remove_variant(row.get_layer(), row.index)


func _draw_cell(row: Row, clip: StringName, frame: int, rect: Rect2, region: Rect2) -> void:
	var inner: Rect2 = rect.grow(-2.0)
	draw_rect(inner, _color(&"dark_color_1", 0.55))
	if row.is_anchor():
		_draw_key(row.get_anchor(), clip, frame, inner)
		return
	
	var animation: StringName = row.get_animation(rig)
	var texture: Texture2D = _frame_texture(row, animation, frame)
	if texture == null:
		return
	
	var fit: float = minf(inner.size.x / region.size.x, inner.size.y / region.size.y)
	fit = floorf(fit) if fit >= 1.0 else fit
	var drawn: Vector2 = region.size * fit
	var tint: Color = Color(1.0, 1.0, 1.0, 1.0 if row.is_active(rig) else 0.4)
	draw_texture_rect_region(texture, Rect2(inner.get_center() - drawn * 0.5, drawn), region, tint)


func _draw_key(anchor: RigAnchor, clip: StringName, frame: int, rect: Rect2) -> void:
	var center: Vector2 = rect.get_center().round()
	var key_color: Color = _color(&"accent_color")
	var blending: bool = (
			anchor.interpolate
			and anchor.get_active_key(clip, frame) != null
			and anchor.get_next_key(clip, frame) != null
	)
	if blending:
		draw_line(center, center + Vector2(rect.size.x + 4.0, 0.0), Color(key_color, 0.45), 2.0)
	if anchor.get_key(clip, frame):
		var radius: float = 6.0
		draw_colored_polygon(
				PackedVector2Array([
					center + Vector2(0.0, -radius),
					center + Vector2(radius, 0.0),
					center + Vector2(0.0, radius),
					center + Vector2(-radius, 0.0),
				]),
				key_color,
		)
	elif anchor.get_active_key(clip, frame):
		draw_circle(center, 1.5, _color(&"font_color", 0.3))


func _draw_drag_feedback(length: int) -> void:
	if not _dragging or _target < 0:
		return
	
	var accent: Color = _color(&"accent_color")
	if _drag == Drag.ROW:
		var y: float = _tops[_target]
		draw_line(Vector2(0.0, y), Vector2(LABEL_WIDTH + length * _cell(), y), accent, 2.0)
	else:
		draw_rect(_cell_rect(_press_cell.y, _target).grow(-1.0), accent, false, 2.0)


func _draw_header(length: int, view: Vector2) -> void:
	draw_rect(Rect2(Vector2(0.0, view.y), Vector2(size.x, HEADER)), _color(&"dark_color_2"))
	for frame: int in length:
		var x: float = LABEL_WIDTH + frame * _cell()
		var current: bool = frame == rig.current_frame
		var color: Color = _color(&"accent_color") if current else _color(&"font_color", 0.55)
		var middle: Vector2 = Vector2(x + _cell() * 0.5, view.y + HEADER * 0.5)
		_draw_text(middle, str(frame + 1), color, -1.0, true)
		var tick: Vector2 = Vector2(x, view.y + HEADER)
		draw_line(tick - Vector2(0.0, 5.0), tick, _color(&"font_color", 0.2))
	if length > 0:
		var head: float = LABEL_WIDTH + (rig.current_frame + 0.5) * _cell()
		var bottom: float = view.y + HEADER
		draw_colored_polygon(
				PackedVector2Array([
					Vector2(head - 5.0, bottom - 6.0),
					Vector2(head + 5.0, bottom - 6.0),
					Vector2(head, bottom),
				]),
				_color(&"accent_color"),
		)


func _draw_labels(view: Vector2) -> void:
	draw_rect(Rect2(Vector2(view.x, 0.0), Vector2(LABEL_WIDTH, size.y)), _color(&"base_color"))
	for i: int in _rows.size():
		var row: Row = _rows[i]
		var band: Rect2 = Rect2(view.x, _tops[i], LABEL_WIDTH, _row_height(i))
		if row.is_section():
			_draw_section_label(row, band)
		else:
			_draw_row_label(row, band, i)
	_draw_tree_lines(view)
	draw_line(
			Vector2(view.x + LABEL_WIDTH, 0.0),
			Vector2(view.x + LABEL_WIDTH, size.y),
			_color(&"font_color", 0.12),
	)


func _draw_tree_lines(view: Vector2) -> void:
	var dim: Color = _color(&"font_color", 0.18)
	var bright: Color = _color(&"font_color", 0.5)
	for parent: int in _rows.size():
		var children: Array[int] = _children_of(parent)
		if children.is_empty():
			continue
		
		var x: float = roundf(view.x + _slot(_rows[parent].get_depth()) + 8.0)
		var top: float = roundf(_middle(parent) + 7.0)
		draw_line(Vector2(x, top), Vector2(x, _middle(children.back())), dim)
		for child: int in children:
			var middle: float = _middle(child)
			var reach: float = 2.0 if _is_foldable(_rows[child]) else 14.0
			var end: float = view.x + _slot(_rows[child].get_depth()) + reach
			var lit: bool = _rows[child].equals(selected)
			if lit:
				draw_line(Vector2(x, top), Vector2(x, middle), bright)
			draw_line(Vector2(x, middle), Vector2(end, middle), bright if lit else dim)


func _children_of(parent: int) -> Array[int]:
	var children: Array[int] = []
	var depth: int = _rows[parent].get_depth()
	for i: int in range(parent + 1, _rows.size()):
		var row: Row = _rows[i]
		if row.get_depth() <= depth:
			break
		if row.get_depth() == depth + 1:
			children.append(i)
	return children


func _draw_row_label(row: Row, band: Rect2, index: int) -> void:
	var middle: float = band.get_center().y
	var hovered: bool = _hover.y == index
	if row.equals(selected):
		draw_rect(band, _color(&"accent_color", 0.22))
	elif hovered:
		draw_rect(band, _color(&"font_color", 0.05))
	
	var depth: int = row.get_depth()
	if _is_foldable(row):
		var open: bool = _expanded.get(row.node, false)
		var arrow: StringName = &"GuiTreeArrowDown" if open else &"GuiTreeArrowRight"
		_draw_icon(arrow, Vector2(band.position.x + _slot(depth), middle), 0.7)
	
	var active: bool = row.is_active(rig)
	var left: float = band.position.x + _slot(depth + 1)
	var right: float = band.end.x - 6.0
	if row.kind == Row.Kind.NODE:
		var shown: bool = (row.node as CanvasItem).visible
		if hovered or not shown:
			var eye: StringName = &"GuiVisibilityVisible" if shown else &"GuiVisibilityHidden"
			_draw_icon(eye, Vector2(right - 16.0, middle), 0.8 if shown else 0.5)
		right -= INDENT + 6.0
	
	var text_color: Color = _color(&"font_color", 1.0 if active else 0.5)
	if row.variant:
		var axis_text: String = "%s:" % row.variant.axis
		_draw_text(Vector2(left, middle), axis_text, _color(&"font_color", 0.4))
		var axis_width: float = _text_width(axis_text) + 6.0
		var value_at: Vector2 = Vector2(left + axis_width, middle)
		_draw_text(value_at, row.variant.value, text_color, right - value_at.x - 4.0)
		return
	
	_draw_icon(row.get_icon(), Vector2(left, middle), 1.0 if active else 0.45)
	_draw_text(Vector2(left + 22.0, middle), row.get_title(), text_color, right - left - 26.0)


func _draw_section_label(row: Row, band: Rect2) -> void:
	draw_rect(band, _color(&"dark_color_2"))
	var middle: float = band.get_center().y
	var open: bool = not _collapsed.get(row.section, false)
	var arrow: StringName = &"GuiTreeArrowDown" if open else &"GuiTreeArrowRight"
	_draw_icon(arrow, Vector2(band.position.x + _slot(0), middle), 0.7)
	var title: String = "Anchors" if row.section == ANCHORS else "Layers"
	var title_at: Vector2 = Vector2(band.position.x + _slot(1), middle)
	_draw_text(title_at, title, _color(&"font_color", 0.85))
	var count_at: Vector2 = title_at + Vector2(_text_width(title) + 8.0, 0.0)
	_draw_text(count_at, str(row.count), _color(&"font_color", 0.4))
	_draw_icon(&"Add", Vector2(band.end.x - INDENT - 6.0, middle), 0.7)


func _draw_corner(length: int, view: Vector2) -> void:
	draw_rect(Rect2(view, Vector2(LABEL_WIDTH, HEADER)), _color(&"dark_color_2"))
	var info: RigClip = rig.get_clip(rig.current_animation)
	var text: String = "Frame %d / %d" % [rig.current_frame + 1, length] if info else "No clip"
	var color: Color = _color(&"font_color", 0.65)
	_draw_text(view + Vector2(8.0, HEADER * 0.5), text, color, LABEL_WIDTH - 16.0)


func _draw_icon(icon_name: StringName, at: Vector2, alpha: float) -> void:
	var icon: Texture2D = get_theme_icon(icon_name, &"EditorIcons")
	if icon:
		var slot: float = 16.0 * EditorInterface.get_editor_scale()
		var corner: Vector2 = at + Vector2(slot - icon.get_width(), -icon.get_height()) * 0.5
		draw_texture(icon, corner.round(), Color(1.0, 1.0, 1.0, alpha))


func _draw_text(
		at: Vector2,
		text: String,
		color: Color,
		max_width: float = -1.0,
		centered: bool = false,
) -> void:
	var font_size: int = get_theme_default_font_size()
	var x: float = at.x - _text_width(text) * 0.5 if centered else at.x
	draw_string(
			get_theme_default_font(),
			Vector2(x, at.y + font_size * 0.35).round(),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			max_width,
			font_size,
			color,
	)


func _text_width(text: String) -> float:
	var font: Font = get_theme_default_font()
	var font_size: int = get_theme_default_font_size()
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _frame_texture(row: Row, animation: StringName, frame: int) -> Texture2D:
	var frames: SpriteFrames = row.get_frames()
	if frame < 0 or frames == null or not frames.has_animation(animation):
		return null
	return frames.get_frame_texture(animation, posmod(frame, frames.get_frame_count(animation)))


func _union(frames: SpriteFrames, animation: StringName) -> Rect2:
	var result: Rect2 = Rect2()
	for texture: Texture2D in RigEdits.textures_of(frames, animation):
		if texture:
			var used: Rect2 = _content_rect(texture)
			result = used if result.size == Vector2.ZERO else result.merge(used)
	return result if result.size != Vector2.ZERO else Rect2(0.0, 0.0, 1.0, 1.0)


func _content_rect(texture: Texture2D) -> Rect2:
	if not _content.has(texture):
		var image: Image = texture.get_image()
		var used: Rect2i = image.get_used_rect() if image else Rect2i()
		var full: Rect2 = Rect2(Vector2.ZERO, texture.get_size())
		_content[texture] = Rect2(used) if used.size != Vector2i.ZERO else full
	return _content[texture]


func _color(color_name: StringName, alpha: float = 1.0) -> Color:
	var color: Color = get_theme_color(color_name, &"Editor")
	return Color(color, color.a * alpha)


func _view() -> Vector2:
	return Vector2(scroll.scroll_horizontal, scroll.scroll_vertical) if scroll else Vector2.ZERO


func _cell() -> float:
	return BASE_CELL * zoom


func _length() -> int:
	if not is_instance_valid(rig) or rig.clips.is_empty():
		return 0
	return rig.get_clip_length(rig.current_animation)


func _slot(depth: int) -> float:
	return 2.0 + depth * INDENT


func _middle(index: int) -> float:
	return roundf(_tops[index] + _row_height(index) * 0.5)


func _is_foldable(row: Row) -> bool:
	return row.kind == Row.Kind.NODE and row.get_layer() and not row.get_layer().variants.is_empty()


func _is_cell(index: int, frame: int) -> bool:
	return index >= 0 and frame >= 0 and frame < _length() and not _rows[index].is_section()


func _row_height(index: int) -> float:
	return _tops[index + 1] - _tops[index]


func _cell_rect(index: int, frame: int) -> Rect2:
	return Rect2(LABEL_WIDTH + frame * _cell(), _tops[index], _cell(), _row_height(index))


func _row_at(y: float) -> int:
	if y < _view().y + HEADER:
		return -2
	for i: int in _rows.size():
		if y < _tops[i + 1]:
			return i
	return -1


func _frame_at(x: float) -> int:
	if x < _view().x + LABEL_WIDTH:
		return -1
	return int((x - LABEL_WIDTH) / _cell())


func _dropped_texture(data: Variant) -> Texture2D:
	var drag: Dictionary = data as Dictionary
	if drag == null or drag.get("type") != "files" or drag.get("files", []).size() != 1:
		return null
	
	var path: String = drag["files"][0]
	return load(path) as Texture2D if path.get_extension() == "png" else null


class Row:
	enum Kind {
		SECTION,
		NODE,
		VARIANT,
	}
	
	var kind: Kind
	var section: StringName
	var node: Node
	var variant: RigVariant
	var index: int
	var count: int = 0
	
	
	func _init(
			row_kind: Kind,
			row_section: StringName,
			row_node: Node = null,
			row_variant: RigVariant = null,
			row_index: int = -1,
	) -> void:
		kind = row_kind
		section = row_section
		node = row_node
		variant = row_variant
		index = row_index
	
	
	func equals(other: Row) -> bool:
		return (
				other != null
				and other.kind == kind
				and other.section == section
				and other.node == node
				and other.variant == variant
		)
	
	
	func get_depth() -> int:
		return int(kind)
	
	
	func is_section() -> bool:
		return kind == Kind.SECTION
	
	
	func is_anchor() -> bool:
		return node is RigAnchor
	
	
	func has_frames() -> bool:
		return node is RigLayer
	
	
	func get_layer() -> RigLayer:
		return node as RigLayer
	
	
	func get_anchor() -> RigAnchor:
		return node as RigAnchor
	
	
	func get_frames() -> SpriteFrames:
		if variant:
			return variant.frames
		return get_layer().frames if get_layer() else null
	
	
	func get_animation(rig: SpriteRig2D) -> StringName:
		return get_layer().resolve(rig.current_animation) if get_layer() else rig.current_animation
	
	
	func get_title() -> String:
		var title: String = String(node.name)
		if is_anchor() and title.ends_with("Anchor") and title != "Anchor":
			return title.trim_suffix("Anchor")
		return title
	
	
	func get_icon() -> StringName:
		return &"Marker2D" if is_anchor() else &"Sprite2D"
	
	
	func is_active(rig: SpriteRig2D) -> bool:
		if variant:
			return rig.get_variant(variant.axis) == variant.value
		return get_layer().is_shown(rig) if get_layer() else true
