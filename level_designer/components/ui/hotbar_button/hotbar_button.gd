class_name LDHotbarButton
extends Button


signal activate_requested(index: int)
signal assign_requested(index: int)
signal clear_requested(index: int)
signal move_requested(from_index: int, to_index: int)


const DRAG_KEY: String = "ld_hotbar_index"
const ADD_ICON: Texture2D = preload("res://assets/textures/level_designer/ui_icons/add.svg")

const ASSIGN_HOLD: float = 0.55
const CLEAR_HOLD: float = 0.7
const HOLD_DEADZONE: float = 0.3
const DECAY_DURATION: float = 0.16
const HOVER_DURATION: float = 0.12
const PUNCH_DURATION: float = 0.34
const PUNCH_SCALE: float = 1.16
const FLASH_DURATION: float = 0.3

const ICON_INSET: float = 4.0
const RING_INSET: float = 1.5
const RING_WIDTH: float = 2.5
const CAPTION_SIZE: int = 10
const EMPTY_LABEL_SIZE: int = 13
const BADGE_PAD: Vector2 = Vector2(2.5, 1.5)
const BADGE_MARGIN: float = 2.5


enum Hold {
	NONE,
	ASSIGN,
	CLEAR,
}


var _index: int = 0
var _slot: LDHotbarSlot = null
var _active: bool = false
var _hold: Hold = Hold.NONE
var _hold_progress: float = 0.0
var _hold_fired: bool = false
var _hover: float = 0.0
var _flash: float = 0.0
var _dragging: bool = false
var _badge_style: StyleBoxFlat = null
var _decay_tween: Tween
var _hover_tween: Tween
var _punch_tween: Tween
var _flash_tween: Tween


func _ready() -> void:
	_badge_style = StyleBoxFlat.new()
	_badge_style.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	_badge_style.set_corner_radius_all(3)
	_badge_style.anti_aliasing = true
	mouse_entered.connect(_on_hover_changed.bind(true))
	mouse_exited.connect(_on_hover_changed.bind(false))
	pivot_offset = size * 0.5
	set_process(false)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			pivot_offset = size * 0.5
		NOTIFICATION_DRAG_BEGIN:
			_cancel_hold()
			if _dragging:
				modulate.a = 0.35
		NOTIFICATION_DRAG_END:
			if not _dragging:
				return
			_dragging = false
			modulate.a = 1.0
			if not get_viewport().gui_is_drag_successful() and not _dropped_on_bar():
				clear_requested.emit(_index)


func bind(index: int, slot: LDHotbarSlot) -> void:
	_index = index
	_slot = slot
	refresh()


func refresh() -> void:
	tooltip_text = _build_tooltip()
	queue_redraw()


func set_active(value: bool) -> void:
	if _active == value:
		return
	_active = value
	if value:
		GDSS.add_class(self, LDUIChromeHandler.ACTIVE_CLASS)
	else:
		GDSS.remove_class(self, LDUIChromeHandler.ACTIVE_CLASS)
	queue_redraw()


func play_landed() -> void:
	_begin_flash()
	_punch()


func play_cleared() -> void:
	_begin_flash()


#region Input

## Accepts every mouse button it handles so [BaseButton] never runs its own press handling. This
## button starts drags, and the drag system swallows the release - which would leave BaseButton's
## press state latched on, and GDSS reads that state to pick the pressed style. The slot's own
## armed look is the Active class, and holding is drawn by _draw_hold_ring().
func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var button_event: InputEventMouseButton = event as InputEventMouseButton
	
	if button_event.button_index == MOUSE_BUTTON_LEFT:
		if button_event.pressed:
			_hold_fired = false
			if _has_capturable_selection():
				_begin_hold(Hold.ASSIGN)
		else:
			var was_click: bool = not _hold_fired and _hold_progress < HOLD_DEADZONE
			_cancel_hold()
			if was_click:
				activate_requested.emit(_index)
		accept_event()
	
	elif button_event.button_index == MOUSE_BUTTON_RIGHT:
		if button_event.pressed:
			_hold_fired = false
			if _is_filled():
				_begin_hold(Hold.CLEAR)
		else:
			_cancel_hold()
		accept_event()


func _process(delta: float) -> void:
	var duration: float = ASSIGN_HOLD if _hold == Hold.ASSIGN else CLEAR_HOLD
	_hold_progress = minf(_hold_progress + delta / duration, 1.0)
	queue_redraw()
	if _hold_progress >= 1.0:
		_complete_hold()


func _begin_hold(kind: Hold) -> void:
	_decay_tween = _kill(_decay_tween)
	_hold = kind
	_hold_progress = 0.0
	set_process(true)
	queue_redraw()


func _complete_hold() -> void:
	var kind: Hold = _hold
	_hold_fired = true
	set_process(false)
	_hold = Hold.NONE
	_hold_progress = 0.0
	queue_redraw()
	
	if kind == Hold.ASSIGN:
		assign_requested.emit(_index)
	elif kind == Hold.CLEAR:
		clear_requested.emit(_index)


func _cancel_hold() -> void:
	set_process(false)
	if _hold == Hold.NONE:
		return
	if _hold_progress <= 0.0 or not _animated():
		_hold = Hold.NONE
		_hold_progress = 0.0
		queue_redraw()
		return
	_decay_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_decay_tween.tween_method(_set_hold_progress, _hold_progress, 0.0, DECAY_DURATION)
	_decay_tween.finished.connect(_on_decay_finished)

#endregion


#region Drag and drop

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not _is_filled():
		return null
	set_drag_preview(_make_drag_preview())
	_dragging = true
	return {DRAG_KEY: _index}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).has(DRAG_KEY)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var from: int = int((data as Dictionary).get(DRAG_KEY, -1))
	if from != _index:
		move_requested.emit(from, _index)


func _make_drag_preview() -> Control:
	var root: Control = Control.new()
	var view: TextureRect = TextureRect.new()
	view.texture = _slot.get_icon()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.size = size
	view.position = -size * 0.5
	view.modulate.a = 0.85
	root.add_child(view)
	return root


func _dropped_on_bar() -> bool:
	var bar: Control = get_parent() as Control
	if not bar:
		return false
	var local: Vector2 = bar.get_global_transform().affine_inverse() * get_global_mouse_position()
	return Rect2(Vector2.ZERO, bar.size).grow(RING_WIDTH * 2.0).has_point(local)

#endregion


#region Drawing

func _draw() -> void:
	if _slot == null:
		return
	if _is_filled():
		_draw_filled()
	else:
		_draw_empty()
	_draw_hold_ring()
	_draw_flash()


func _draw_empty() -> void:
	var reveal: float = _hover if _animated() else float(_hover > 0.5)
	if reveal < 1.0:
		_draw_centered_label(str(_index + 1), EMPTY_LABEL_SIZE, Color(1.0, 1.0, 1.0, 0.42 * (1.0 - reveal)))
	if reveal > 0.0:
		var span: float = minf(size.x, size.y) * 0.42
		var box: Rect2 = Rect2((size - Vector2(span, span)) * 0.5, Vector2(span, span))
		draw_texture_rect(ADD_ICON, box, false, Color(1.0, 1.0, 1.0, 0.6 * reveal))


func _draw_filled() -> void:
	var icon_texture: Texture2D = _slot.get_icon()
	var drain: float = _hold_progress if _hold == Hold.CLEAR else 0.0
	if icon_texture:
		var tint: Color = Color(1.0, 1.0 - drain * 0.55, 1.0 - drain * 0.55, 1.0 - drain * 0.7)
		draw_texture_rect(icon_texture, _fit(icon_texture.get_size()), false, tint)
	else:
		_draw_centered_label("?", EMPTY_LABEL_SIZE, Color(1.0, 1.0, 1.0, 0.4))
	
	if _slot.get_count() > 1:
		_draw_badge("%d" % _slot.get_count(), false, Color(LDPalette.accent(), 1.0 - drain))
	
	var reveal: float = _hover if _animated() else float(_hover > 0.5)
	if reveal > 0.0:
		_draw_badge(str(_index + 1), true, Color(1.0, 1.0, 1.0, 0.85 * reveal))


func _draw_hold_ring() -> void:
	if _hold_progress <= HOLD_DEADZONE:
		return
	var shown: float = (_hold_progress - HOLD_DEADZONE) / (1.0 - HOLD_DEADZONE)
	var tint: Color = LDPalette.danger() if _hold == Hold.CLEAR else LDPalette.accent()
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5 - RING_INSET
	draw_arc(center, radius, 0.0, TAU, 48, Color(tint, 0.18), RING_WIDTH, true)
	draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * shown, 48, Color(tint, 0.95), RING_WIDTH, true)


func _draw_flash() -> void:
	if _flash <= 0.0:
		return
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5 - RING_INSET
	draw_arc(center, radius + (1.0 - _flash) * 5.0, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.55 * _flash), RING_WIDTH * _flash, true)


func _draw_badge(text: String, leading: bool, tint: Color) -> void:
	var font: Font = get_theme_font(&"font")
	var span: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_SIZE)
	span.y = font.get_ascent(CAPTION_SIZE)
	var box: Vector2 = span + BADGE_PAD * 2.0
	var at: Vector2 = Vector2(BADGE_MARGIN, BADGE_MARGIN) if leading else size - box - Vector2(BADGE_MARGIN, BADGE_MARGIN)
	_badge_style.bg_color.a = 0.6 * tint.a
	draw_style_box(_badge_style, Rect2(at, box))
	draw_string(font, at + BADGE_PAD + Vector2(0.0, span.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_SIZE, tint)


func _draw_centered_label(text: String, font_size: int, tint: Color) -> void:
	var font: Font = get_theme_font(&"font")
	var span: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var origin: Vector2 = Vector2((size.x - span.x) * 0.5, (size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)


func _fit(source: Vector2) -> Rect2:
	var box: Vector2 = size - Vector2(ICON_INSET, ICON_INSET) * 2.0
	if source.x <= 0.0 or source.y <= 0.0:
		return Rect2(Vector2(ICON_INSET, ICON_INSET), box)
	var span: Vector2 = source * minf(box.x / source.x, box.y / source.y)
	return Rect2((size - span) * 0.5, span)

#endregion


#region Internal

func _is_filled() -> bool:
	return _slot != null and not _slot.is_empty() and _slot.is_valid()


func _has_capturable_selection() -> bool:
	return not LD.get_object_handler().get_placed_selection().is_empty()


func _build_tooltip() -> String:
	var key: String = "[%d]  " % (_index + 1)
	if not _is_filled():
		return key + "Empty slot\nClick to pick an object\nHold to save the selection"
	return key + _slot.get_label() + "\nHold to replace  ·  Right-hold to clear\nDrag to reorder, or off the bar to clear"


func _on_hover_changed(value: bool) -> void:
	_hover_tween = _kill(_hover_tween)
	var target: float = 1.0 if value else 0.0
	if not _animated():
		_set_hover(target)
		return
	_hover_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_hover_tween.tween_method(_set_hover, _hover, target, HOVER_DURATION)


func _begin_flash() -> void:
	_flash_tween = _kill(_flash_tween)
	if not _animated():
		return
	_flash = 1.0
	_flash_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_flash_tween.tween_method(_set_flash, 1.0, 0.0, FLASH_DURATION)


func _punch() -> void:
	_punch_tween = _kill(_punch_tween)
	scale = Vector2.ONE
	if not _animated():
		return
	_punch_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_punch_tween.tween_property(self, ^"scale", Vector2(PUNCH_SCALE, PUNCH_SCALE), PUNCH_DURATION * 0.35)
	_punch_tween.tween_property(self, ^"scale", Vector2.ONE, PUNCH_DURATION * 0.65)


func _on_decay_finished() -> void:
	_hold = Hold.NONE
	queue_redraw()


func _set_hold_progress(value: float) -> void:
	_hold_progress = value
	queue_redraw()


func _set_hover(value: float) -> void:
	_hover = value
	queue_redraw()


func _set_flash(value: float) -> void:
	_flash = value
	queue_redraw()


func _kill(tween: Tween) -> Tween:
	if is_instance_valid(tween):
		tween.kill()
	return null


func _animated() -> bool:
	return Settings.get_bool(&"display/ui_animations")

#endregion
