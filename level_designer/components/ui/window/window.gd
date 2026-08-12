class_name LDWindow
extends CanvasLayer

## The single modal shell every level designer panel is shown in. [LDUIWindowHandler] binds one
## content node at a time; the shell owns the framing, the open/close animation, and the window's
## position and size, which are remembered per panel across sessions.


signal popped_in
signal popped_out

## CLOSED and OPEN are resting states; the two -ING states mean a tween is running. Every
## transition kills the previous tween, so a superseded animation simply never reports back.
enum WindowState { CLOSED, OPENING, OPEN, CLOSING }


const MIN_SIZE: Vector2 = Vector2(200.0, 120.0)
const SCREEN_MARGIN: float = 8.0
const ANIM_DURATION: float = 0.15
const START_SCALE: Vector2 = Vector2(0.6, 0.6)


@export var title: String:
	set(t):
		title = t
		if _title_label:
			_title_label.text = t
			_title_label.visible = not t.is_empty()

## Closes when the "back" input event is pressed.
@export var close_on_back_input: bool = false

@export var window_scale: Vector2 = Vector2.ONE

@export_group("Sound", "sfx")
@export var sfx_on_open: bool = true
@export var sfx_on_close: bool = true

@export_group("Backdrop", "backdrop")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "backdrop") var backdrop_enabled: bool = true
@export var backdrop_block_input: bool = true
@export var backdrop_color: Color = Color(0, 0, 0, 0.4)
@export_custom(PROPERTY_HINT_RANGE, "0,16") var backdrop_blur: float = 1.5

@export_group("Internal")
@export var _panel: PanelContainer
@export var _content_container: PanelContainer
@export var _title_label: Label
@export var _backdrop: ColorRect
@export var _title_bar: Control
@export var _resize_grip: Control


var _state: WindowState = WindowState.CLOSED
var _content_ref: Control
var _active_id: StringName = &""
var _tween: Tween
var _drag_from: Vector2 = Vector2.ZERO
var _resize_from: Vector2 = Vector2.ZERO
var _resize_size: Vector2 = Vector2.ZERO
var _backdrop_alpha: float = 0.0:
	set(v):
		_backdrop_alpha = v
		if _backdrop and _backdrop.material:
			var mat: ShaderMaterial = _backdrop.material as ShaderMaterial
			mat.set_shader_parameter(&"tint", Color(backdrop_color.r, backdrop_color.g, backdrop_color.b, backdrop_color.a * v))
			mat.set_shader_parameter(&"blur", backdrop_blur * v)


func _init() -> void:
	visible = false


func _ready() -> void:
	_title_label.text = title
	if title.is_empty():
		_title_label.hide()
	_setup_backdrop()
	if _title_bar:
		_title_bar.gui_input.connect(_on_title_bar_input)
	if _resize_grip:
		_resize_grip.gui_input.connect(_on_resize_grip_input)


func _input(event: InputEvent) -> void:
	if close_on_back_input and event.is_action_pressed("_ui_back"):
		popout()


func is_open() -> bool:
	return _state == WindowState.OPEN or _state == WindowState.OPENING


## Adds a content node to the shell, kept hidden until it is bound. Contents are never reparented
## or freed once added, so each panel keeps its state across opens.
func add_content(control: Control) -> void:
	if not control:
		return
	control.visible = false
	_content_container.add_child(control)


## Makes [param control] the active content and applies that panel's shell settings. The control
## must already have been handed over by [method add_content].
func bind(control: Control, def: LDWindowDef) -> void:
	_remember_geometry()
	_active_id = def.id
	title = def.title
	close_on_back_input = def.close_on_back_input
	window_scale = def.window_scale
	for child: Node in _content_container.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = child == control
	_content_ref = control
	if _state == WindowState.OPEN:
		# Swapping panels while open: no animation, just refit to the new content.
		_apply_geometry.call_deferred()


func get_content_ref() -> Control:
	return _content_ref


func popin() -> void:
	if is_open():
		return
	_set_tween(null)
	_set_state(WindowState.OPENING)

	if sfx_on_open:
		SFX.play(SFX.LD_OPEN)
	if is_instance_valid(_content_ref) and _content_ref.has_method(&"_on_show"):
		_content_ref.call(&"_on_show")

	visible = true
	_panel.scale = START_SCALE
	_panel.modulate = Color.TRANSPARENT
	# Deferred so the container has re-sorted for the newly visible content; measuring this frame
	# reads a stale minimum size and the window comes up fitted to whatever was shown last.
	_apply_geometry.call_deferred()

	if backdrop_enabled and _backdrop:
		_backdrop_alpha = 0.0
		_backdrop.visible = true

	var tween: Tween = create_tween().set_parallel()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	tween.tween_property(_panel, "scale", window_scale, ANIM_DURATION)
	tween.tween_property(_panel, "modulate", Color.WHITE, ANIM_DURATION)
	if backdrop_enabled and _backdrop:
		tween.tween_property(self, "_backdrop_alpha", 1.0, ANIM_DURATION * 2.0)
	tween.finished.connect(_on_popin_finished)
	_set_tween(tween)


func popout() -> void:
	if _state == WindowState.CLOSED or _state == WindowState.CLOSING:
		return
	_remember_geometry()
	_set_tween(null)
	_set_state(WindowState.CLOSING)

	if sfx_on_close:
		SFX.play(SFX.LD_CLOSE)

	var tween: Tween = create_tween().set_parallel()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	tween.tween_property(_panel, "scale", START_SCALE, ANIM_DURATION)
	tween.tween_property(_panel, "modulate", Color.TRANSPARENT, ANIM_DURATION)
	if backdrop_enabled and _backdrop:
		tween.tween_property(self, "_backdrop_alpha", 0.0, ANIM_DURATION)
	tween.finished.connect(_on_popout_finished)
	_set_tween(tween)


func _on_popin_finished() -> void:
	_set_state(WindowState.OPEN)
	popped_in.emit()


func _on_popout_finished() -> void:
	_set_state(WindowState.CLOSED)
	visible = false
	if backdrop_enabled and _backdrop:
		_backdrop.visible = false
	popped_out.emit()
	if is_instance_valid(_content_ref) and _content_ref.has_method(&"_on_hide"):
		_content_ref.call(&"_on_hide")


func _set_state(state: WindowState) -> void:
	_state = state


## Replaces the running tween, killing the old one. A killed tween never emits `finished`, so the
## callback of a superseded animation is dropped without needing to be checked for staleness.
func _set_tween(tween: Tween) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = tween


#region Geometry

## Restores where this panel was last left, or fits and centres it the first time it is opened.
func _apply_geometry() -> void:
	var stored: Rect2 = LDEditorConfig.get_window_rect(_active_id)
	if stored.size == Vector2.ZERO:
		_panel.reset_size()
		_panel.position = ((_viewport_size() - _panel.size) / 2.0).floor()
	else:
		_panel.size = stored.size
		_panel.position = stored.position
	_clamp_to_viewport()


func _remember_geometry() -> void:
	if _active_id.is_empty() or _state == WindowState.CLOSED:
		return
	LDEditorConfig.set_window_rect(_active_id, Rect2(_panel.position, _panel.size))


func _clamp_to_viewport() -> void:
	var limit: Vector2 = _viewport_size() - _panel.size
	_panel.position = _panel.position.clamp(
		Vector2(SCREEN_MARGIN, SCREEN_MARGIN),
		Vector2(maxf(limit.x - SCREEN_MARGIN, SCREEN_MARGIN), maxf(limit.y - SCREEN_MARGIN, SCREEN_MARGIN))
	)


func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _on_title_bar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if (event as InputEventMouseButton).pressed:
			_drag_from = _title_bar.get_global_mouse_position() - _panel.position
			_title_bar.set_meta(&"dragging", true)
		else:
			_title_bar.remove_meta(&"dragging")
			_remember_geometry()
	elif event is InputEventMouseMotion and _title_bar.has_meta(&"dragging"):
		_panel.position = _title_bar.get_global_mouse_position() - _drag_from
		_clamp_to_viewport()


func _on_resize_grip_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if (event as InputEventMouseButton).pressed:
			_resize_from = _resize_grip.get_global_mouse_position()
			_resize_size = _panel.size
			_resize_grip.set_meta(&"resizing", true)
		else:
			_resize_grip.remove_meta(&"resizing")
			_remember_geometry()
	elif event is InputEventMouseMotion and _resize_grip.has_meta(&"resizing"):
		var wanted: Vector2 = _resize_size + (_resize_grip.get_global_mouse_position() - _resize_from)
		_panel.size = wanted.max(MIN_SIZE.max(_panel.get_combined_minimum_size()))
		_clamp_to_viewport()

#endregion


func _setup_backdrop() -> void:
	if not backdrop_enabled or not _backdrop:
		return

	_backdrop.visible = false
	_backdrop_alpha = 0.0

	if backdrop_block_input:
		_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		_backdrop.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventScreenTouch and ev.is_pressed():
				popout()
		)
	else:
		_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_close_button_pressed() -> void:
	popout()
