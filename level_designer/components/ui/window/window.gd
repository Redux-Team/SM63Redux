class_name LDWindow
extends CanvasLayer

## The single modal shell every level designer panel is shown in. [LDUIWindowHandler] binds one
## content node at a time; the shell owns the framing and the open/close animation. The window
## is always centred at its content's natural size, and is neither movable nor resizable.


signal popped_in
signal popped_out

## CLOSED and OPEN are resting states; the two -ING states mean a tween is running. Every
## transition kills the previous tween, so a superseded animation simply never reports back.
enum WindowState { CLOSED, OPENING, OPEN, CLOSING }


const ANIM_DURATION: float = 0.15
## Fraction of the final size the pop-in starts from.
const START_RATIO: float = 0.6


@export var title: String:
	set(t):
		title = t
		if _title_label:
			_title_label.text = t
			_title_label.visible = not t.is_empty()

## Closes when the "back" input event is pressed.
@export var close_on_back_input: bool = false

## Per-panel size multiplier, on top of the editor-wide [method LDUI.get_ui_scale].
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


var _state: WindowState = WindowState.CLOSED
var _content_ref: Control
var _backdrop_alpha: float = 0.0:
	set(v):
		_backdrop_alpha = v
		if not _backdrop:
			return
		
		# The blur writes COLOR outright, so the flat tint is only what shows once [ScreenEffects]
		# has taken the material away - but keeping both in step means the toggle can land at any
		# point in the animation without a frame of the wrong colour.
		_backdrop.color = Color(backdrop_color, backdrop_color.a * v)
		var mat: ShaderMaterial = _backdrop.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter(&"tint", _backdrop.color)
			mat.set_shader_parameter(&"blur", backdrop_blur * v)
var _tween: Tween


func _init() -> void:
	visible = false


func _ready() -> void:
	_title_label.text = title
	if title.is_empty():
		_title_label.hide()
	_setup_backdrop()


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
	title = def.title
	close_on_back_input = def.close_on_back_input
	window_scale = def.window_scale
	for child: Node in _content_container.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = child == control
	_content_ref = control
	if _state == WindowState.OPEN:
		# Swapping panels while open: no animation, just refit to the new content.
		_panel.scale = _target_scale()
		_refit.call_deferred()


func get_content_ref() -> Control:
	return _content_ref


func popin() -> void:
	if is_open():
		return
	_set_tween(null)
	_state = WindowState.OPENING

	if sfx_on_open:
		SFX.play(SFX.LD_OPEN)
	if is_instance_valid(_content_ref) and _content_ref.has_method(&"_on_show"):
		_content_ref.call(&"_on_show")

	visible = true
	_panel.scale = _target_scale() * START_RATIO
	_panel.modulate = Color.TRANSPARENT
	# Deferred so the container has re-sorted for the newly visible content; measuring this frame
	# reads a stale minimum size and the window comes up fitted to whatever was shown last.
	_refit.call_deferred()

	if backdrop_enabled and _backdrop:
		_backdrop_alpha = 0.0
		_backdrop.visible = true

	if not Settings.get_bool(&"display/ui_animations"):
		_panel.scale = _target_scale()
		_panel.modulate = Color.WHITE
		if backdrop_enabled and _backdrop:
			_backdrop_alpha = 1.0
		_on_popin_finished()
		return

	var tween: Tween = create_tween().set_parallel()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	tween.tween_property(_panel, "scale", _target_scale(), ANIM_DURATION)
	tween.tween_property(_panel, "modulate", Color.WHITE, ANIM_DURATION)
	if backdrop_enabled and _backdrop:
		tween.tween_property(self, "_backdrop_alpha", 1.0, ANIM_DURATION * 2.0)
	tween.finished.connect(_on_popin_finished)
	_set_tween(tween)


func popout() -> void:
	if _state == WindowState.CLOSED or _state == WindowState.CLOSING:
		return
	_set_tween(null)
	_state = WindowState.CLOSING

	if sfx_on_close:
		SFX.play(SFX.LD_CLOSE)

	if not Settings.get_bool(&"display/ui_animations"):
		if backdrop_enabled and _backdrop:
			_backdrop_alpha = 0.0
		_on_popout_finished()
		return

	var tween: Tween = create_tween().set_parallel()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	tween.tween_property(_panel, "scale", _target_scale() * START_RATIO, ANIM_DURATION)
	tween.tween_property(_panel, "modulate", Color.TRANSPARENT, ANIM_DURATION)
	if backdrop_enabled and _backdrop:
		tween.tween_property(self, "_backdrop_alpha", 0.0, ANIM_DURATION)
	tween.finished.connect(_on_popout_finished)
	_set_tween(tween)


func _on_popin_finished() -> void:
	_state = WindowState.OPEN
	popped_in.emit()


func _on_popout_finished() -> void:
	_state = WindowState.CLOSED
	visible = false
	if backdrop_enabled and _backdrop:
		_backdrop.visible = false
	popped_out.emit()
	if is_instance_valid(_content_ref) and _content_ref.has_method(&"_on_hide"):
		_content_ref.call(&"_on_hide")


## Replaces the running tween, killing the old one. A killed tween never emits `finished`, so the
## callback of a superseded animation is dropped without needing to be checked for staleness.
func _set_tween(tween: Tween) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = tween


func _target_scale() -> Vector2:
	return window_scale * LDUI.get_ui_scale()


## Refits the panel to whichever content is now visible and re-centres it. Resizing alone leaves
## the top-left corner where the previous, larger panel had it, so the window sits off-centre.
func _refit() -> void:
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func _setup_backdrop() -> void:
	if not backdrop_enabled or not _backdrop:
		return

	ScreenEffects.apply(_backdrop, _backdrop.material)
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
