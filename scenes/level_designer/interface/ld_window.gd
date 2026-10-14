class_name LDWindow
extends Panel

signal closed

const ANIM_DURATION: float = 0.18
const START_RATIO: float = 0.7
const START_ROTATION: float = -0.06
const SWITCH_DURATION: float = 0.16

@export var fade: Control
@export var frame: PanelContainer
@export var content: Container
@export var title_plate: Control
@export var title_margin: MarginContainer
@export var title_space: int = 18
@export var title_label: Label
@export var close_button: BaseButton
@export var backdrop: BlurRect
@export var glass: Panel
@export var glass_tint: float = 0.8
@export var backdrop_tint: Color = Color(0.0, 0.0, 0.0, 0.4)
@export var screen_margin: float = 16.0

var _view_scale: Vector2 = Vector2.ONE
var _fit: float = 1.0
var _presence: float = 0.0
var _open: bool = false
var _tween: Tween


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)
	backdrop.gui_input.connect(_on_backdrop_input)
	get_viewport().size_changed.connect(_on_viewport_resized)
	set_process(false)


func _process(_delta: float) -> void:
	glass.position = frame.position
	glass.size = frame.size
	glass.pivot_offset = frame.pivot_offset
	glass.scale = frame.scale
	glass.rotation = frame.rotation
	var weight: float = _presence
	GDSS.set_instance_var(glass, "window_blur", 5.0 * Settings.ui.blur_strength.current_value / 100.0 * weight)
	GDSS.set_instance_var(glass, "window_tint", glass_tint * weight)
	GDSS.set_instance_var(glass, "window_edge", weight)


func is_open() -> bool:
	return _open


func set_title(title: String) -> void:
	title_label.text = title
	title_plate.visible = not title.is_empty()
	title_margin.add_theme_constant_override(&"margin_top", title_space if title_plate.visible else 0)


func show_view(view: Control, title: String, view_scale: Vector2) -> void:
	if _open:
		_switch(view, title, view_scale)
		return
	
	_apply(view, title, view_scale)
	_open = true
	visible = true
	set_process(true)
	SFX.play(SFX.LD_OPEN)
	frame.scale = _target_scale() * START_RATIO
	frame.rotation = START_ROTATION
	fade.modulate = Color.TRANSPARENT
	_animate(_target_scale(), 0.0, Color.WHITE, 1.0)


func close() -> void:
	if not _open:
		return
	
	_open = false
	SFX.play(SFX.LD_CLOSE)
	_animate(_target_scale() * START_RATIO, -START_ROTATION, Color.TRANSPARENT, 0.0).finished.connect(_on_closed)


func _apply(view: Control, title: String, view_scale: Vector2) -> void:
	if view.get_parent() != content:
		view.reparent(content, false)
		_release_scrollbars(view)
	
	for child: Node in content.get_children():
		(child as Control).visible = child == view
	
	set_title(title)
	_view_scale = view_scale
	fit()
	fit.call_deferred()


func _switch(view: Control, title: String, view_scale: Vector2) -> void:
	if view.get_parent() == content and view.visible:
		return
	
	if not Settings.ui.animations.current_value:
		_apply(view, title, view_scale)
		return
	
	if _tween and _tween.is_valid():
		_tween.kill()
	
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(fade, ^"modulate", Color.TRANSPARENT, SWITCH_DURATION / 2.0)
	_tween.tween_callback(_apply.bind(view, title, view_scale))
	_tween.tween_property(fade, ^"modulate", Color.WHITE, SWITCH_DURATION / 2.0)


func _animate(target_scale: Vector2, target_rotation: float, target_modulate: Color, backdrop_weight: float) -> Tween:
	if _tween and _tween.is_valid():
		_tween.kill()
	
	var duration: float = ANIM_DURATION if Settings.ui.animations.current_value else 0.0
	_tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(frame, ^"scale", target_scale, duration)
	_tween.tween_property(frame, ^"rotation", target_rotation, duration)
	_tween.tween_property(fade, ^"modulate", target_modulate, duration).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, ^"_presence", target_modulate.a, duration).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_method(_set_backdrop, 1.0 - backdrop_weight, backdrop_weight, duration * 1.5).set_trans(Tween.TRANS_CUBIC)
	return _tween


func _set_backdrop(weight: float) -> void:
	backdrop.blur_strength = 5.0 * Settings.ui.blur_strength.current_value / 100.0 * weight
	backdrop.tint = Color(backdrop_tint, backdrop_tint.a * weight)


func fit() -> void:
	frame.reset_size()
	var screen: Vector2 = get_viewport_rect().size
	var available: Vector2 = screen - Vector2.ONE * screen_margin * 2.0
	_fit = minf(1.0, minf(available.x / frame.size.x, available.y / frame.size.y))
	frame.pivot_offset = frame.size / 2.0
	frame.position = ((screen - frame.size) / 2.0).round()
	if _tween == null or not _tween.is_running():
		frame.scale = _target_scale()


func _release_scrollbars(view: Control) -> void:
	for scroll: Node in view.find_children("*", "ScrollContainer", true, false):
		GDSS.disable_gdss((scroll as ScrollContainer).get_v_scroll_bar())
		GDSS.disable_gdss((scroll as ScrollContainer).get_h_scroll_bar())


func _target_scale() -> Vector2:
	return _view_scale * _fit


func _on_viewport_resized() -> void:
	if _open:
		fit.call_deferred()


func _on_closed() -> void:
	visible = false
	set_process(false)
	closed.emit()


func _on_backdrop_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button and button.pressed:
		close()
