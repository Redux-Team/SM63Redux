@tool
class_name UISlider
extends HSlider

@export var fill: Panel
@export var grabber: Panel
@export_range(0.0, 16.0, 1.0, "suffix:px") var inset: float = 4.0:
	set(value):
		inset = value
		_rebuild_ticks()
@export var tick_size: Vector2 = Vector2(2.0, 5.0):
	set(value):
		tick_size = value
		_rebuild_ticks()

var _ticks: Dictionary[Panel, float] = {}
var _hovered: bool = false
var _held: bool = false


func _ready() -> void:
	value_changed.connect(_update_layout.unbind(1))
	changed.connect(_update_layout)
	resized.connect(_place_ticks)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	focus_entered.connect(_update_state)
	focus_exited.connect(_update_state)
	if not Engine.is_editor_hint() and grabber != null:
		var grabber_icon: PlaceholderTexture2D = PlaceholderTexture2D.new()
		grabber_icon.size = Vector2(grabber.size.x + inset * 2.0, grabber.size.y)
		for icon_name: StringName in [&"grabber", &"grabber_highlight", &"grabber_disabled"]:
			add_theme_icon_override(icon_name, grabber_icon)
	_rebuild_ticks()


func _gui_input(event: InputEvent) -> void:
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		_held = mouse_button.pressed
		_update_state()


func _set(property: StringName, _value: Variant) -> bool:
	if property == &"tick_count" or property == &"ticks_on_borders":
		_rebuild_ticks.call_deferred()
	return false


func is_held() -> bool:
	return _held


func _update_layout() -> void:
	if fill == null or grabber == null:
		return
	var grabber_width: float = grabber.size.x
	var shift: float = (grabber_width + inset * 2.0) * ratio
	grabber.set_anchor_and_offset(SIDE_LEFT, ratio, inset - shift, true)
	grabber.set_anchor_and_offset(SIDE_RIGHT, ratio, inset - shift + grabber_width)
	fill.set_anchor_and_offset(SIDE_RIGHT, ratio, grabber_width + inset * 2.0 - shift)
	for tick: Panel in _ticks:
		if _ticks[tick] <= ratio:
			GDSS.set_state(tick, "filled")
		else:
			GDSS.clear_state(tick)


func _rebuild_ticks() -> void:
	for tick: Panel in _ticks:
		tick.queue_free()
	_ticks.clear()
	if grabber == null or not is_inside_tree():
		return
	for i: int in tick_count:
		if tick_count < 2 or (not ticks_on_borders and (i == 0 or i == tick_count - 1)):
			continue
		var tick: Panel = Panel.new()
		tick.mouse_filter = MOUSE_FILTER_IGNORE
		GDSS.add_class(tick, "TickMark")
		add_child(tick)
		move_child(tick, grabber.get_index())
		_ticks[tick] = float(i) / float(tick_count - 1)
	_place_ticks()
	_update_layout()


func _place_ticks() -> void:
	if grabber == null:
		return
	var span: float = grabber.size.x + inset * 2.0
	for tick: Panel in _ticks:
		var center: float = span * 0.5 + _ticks[tick] * (size.x - span)
		tick.position = \
				Vector2(roundf(center - tick_size.x * 0.5), roundf((size.y - tick_size.y) * 0.5))
		tick.size = tick_size


func _set_hovered(hovered: bool) -> void:
	_hovered = hovered
	_update_state()


func _update_state() -> void:
	if grabber == null:
		return
	if not editable:
		GDSS.set_state(grabber, "disabled")
	elif _held:
		GDSS.set_state(grabber, "pressed")
	elif _hovered or has_focus(true):
		GDSS.set_state(grabber, "active")
	else:
		GDSS.clear_state(grabber)
