@tool
class_name PausePanel
extends PanelContainer

@export var slant: float = 0.2:
	set(value):
		slant = value
		_queue_layout()
@export var edge_padding: float = 16.0:
	set(value):
		edge_padding = value
		_queue_layout()
@export var side_padding: float = 32.0:
	set(value):
		side_padding = value
		_queue_layout()
@export var margin_container: MarginContainer:
	set(value):
		margin_container = value
		_queue_layout()
@export var buttons: SlopeBoxContainer:
	set(value):
		if buttons and buttons.minimum_size_changed.is_connected(_queue_layout):
			buttons.minimum_size_changed.disconnect(_queue_layout)
			buttons.item_rect_changed.disconnect(_place_header)
			buttons.sort_children.disconnect(_place_header)
		buttons = value
		if buttons:
			buttons.minimum_size_changed.connect(_queue_layout)
			buttons.item_rect_changed.connect(_place_header)
			buttons.sort_children.connect(_place_header)
		_queue_layout()
@export var header: Control:
	set(value):
		if header and header.resized.is_connected(_place_header):
			header.resized.disconnect(_place_header)
		header = value
		if header:
			header.resized.connect(_place_header)
		_place_header()
@export var header_gap: float = 16.0:
	set(value):
		header_gap = value
		_place_header()
@export_range(0.0, 1.0) var expansion: float = 0.0:
	set(value):
		expansion = value
		_queue_layout()

var _layout_queued: bool = false
var _fitted_width: float = 0.0


func _ready() -> void:
	var parent: Control = get_parent_control()
	if parent:
		parent.resized.connect(_queue_layout)
	_queue_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_queue_layout()


func _queue_layout() -> void:
	if _layout_queued or not is_inside_tree():
		return
	
	_layout_queued = true
	_layout.call_deferred()


func _layout() -> void:
	_layout_queued = false
	if not margin_container or not buttons:
		return
	
	var rows: Array[Control] = []
	for child: Node in buttons.get_children():
		if child is Control and (child as Control).visible:
			rows.append(child)
	if rows.is_empty():
		return
	
	var content: Vector2 = buttons.get_minimum_size()
	var first_half: float = rows[0].get_combined_minimum_size().y / 2.0
	var last_half: float = rows[-1].get_combined_minimum_size().y / 2.0
	var spread: float = (content.y - first_half - last_half) * slant
	var margin_top: float = margin_container.get_theme_constant(&"margin_top")
	var margin_bottom: float = margin_container.get_theme_constant(&"margin_bottom")
	var space: float = size.y - margin_top - margin_bottom
	var first_center: float = margin_top + (space - content.y) / 2.0 + first_half
	var left: float = first_center * slant + edge_padding
	
	var fitted: float = left + content.x + spread + side_padding
	_fitted_width = fitted
	var parent: Control = get_parent_control()
	var full: float = maxf(parent.size.x, fitted) if parent else fitted
	var width: float = ceilf(lerpf(fitted, full, expansion))
	
	buttons.slope = slant
	_set_min_width(buttons, content.x + spread)
	_set_margin(&"margin_left", roundi(left + width - fitted))
	_set_margin(&"margin_right", roundi(side_padding))
	_set_min_width(self, width)
	_update_clip()
	_place_header()


func _place_header() -> void:
	if not header or not buttons or not margin_container:
		return
	
	var first: Control = null
	for child: Node in buttons.get_children():
		if child is Control and (child as Control).visible:
			first = child
			break
	if not first:
		return
	
	var top: float = margin_container.position.y + buttons.position.y + first.position.y
	var header_size: Vector2 = header.get_combined_minimum_size()
	var center_y: float = top - header_gap - header_size.y / 2.0
	var left: float = slant * center_y + edge_padding
	var right: float = _fitted_width - side_padding
	var grown: float = maxf(size.x - _fitted_width, 0.0)
	header.size = header_size
	header.position = (Vector2((left + right) / 2.0 + grown, center_y) - header_size / 2.0).round()


func _update_clip() -> void:
	if Engine.is_editor_hint() or is_zero_approx(size.x):
		return
	
	var bottom: float = slant * size.y / size.x * (1.0 - expansion)
	var clip: GdssClipPath = GdssClipPath.new()
	clip.points = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(bottom, 1.0),
	])
	var current: Variant = GDSS.get_prop_overrides(self).get("clip_path")
	if current is GdssClipPath and (current as GdssClipPath).points == clip.points:
		return
	
	GDSS.set_prop_override(self, "clip_path", clip)


func _set_min_width(control: Control, width: float) -> void:
	if not is_equal_approx(control.custom_minimum_size.x, width):
		control.custom_minimum_size.x = width


func _set_margin(margin: StringName, value: int) -> void:
	if (
			not margin_container.has_theme_constant_override(margin)
			or margin_container.get_theme_constant(margin) != value
	):
		margin_container.add_theme_constant_override(margin, value)
