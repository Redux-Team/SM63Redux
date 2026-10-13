class_name Tooltip
extends CanvasLayer

enum Placement {
	AUTO,
	LEFT,
	RIGHT,
	UNDER,
	ABOVE,
}

const TEXT_META: StringName = &"tooltip"
const MODE_META: StringName = &"tooltip_mode"
const FOCUS_META: StringName = &"tooltip_on_focus"
const ARROW_LENGTH: float = 6.0
const ARROW_WIDTH: float = 10.0
const ARROW_CLASSES: Dictionary[Placement, String] = {
	Placement.UNDER: "TooltipArrow",
	Placement.ABOVE: "TooltipArrowDown",
	Placement.RIGHT: "TooltipArrowLeft",
	Placement.LEFT: "TooltipArrowRight",
}
const AUTO_ORDER: Array[Placement] = [Placement.UNDER, Placement.ABOVE, Placement.RIGHT, Placement.LEFT]
const WARM_TIME: float = 0.4

@export var root: Control
@export var bubble: PanelContainer
@export var label: RichTextLabel
@export var arrow: Panel
@export var gap: float = 3.0
@export var overlap: float = 1.0
@export var margin: float = 4.0
@export var slide: float = 4.0
@export var fade_duration: float = 0.12
@export var tint: float = 0.6

var _target: Control
var _hover_time: float = 0.0
var _shown: bool = false
var _mode: Placement = Placement.UNDER
var _slide: Vector2 = Vector2.ZERO
var _warm: float = 0.0
var _tween: Tween


static func set_text(control: Control, text: String, mode: Placement = Placement.AUTO) -> void:
	control.tooltip_text = ""
	control.set_meta(TEXT_META, text)
	control.set_meta(MODE_META, mode)


static func get_text(control: Control) -> String:
	return control.get_meta(TEXT_META, "")


func _ready() -> void:
	root.modulate = Color.TRANSPARENT
	root.visible = false
	_set_fade(0.0)


func _process(delta: float) -> void:
	var target: Control = _current_target() if Settings.level_designer.is_tooltip_enabled() else null
	if target != _target:
		var was_shown: bool = _shown
		_target = target
		_hover_time = 0.0
		if was_shown:
			_warm = WARM_TIME
		if was_shown and target:
			_show(false)
		else:
			_hide()
	
	if not _shown:
		_warm = maxf(_warm - delta, 0.0)
	
	if _target == null:
		return
	
	_hover_time += delta
	if not _shown and (_warm > 0.0 or _hover_time >= Settings.level_designer.tooltip_delay.current_value):
		_show(_warm <= 0.0)
	
	if _shown:
		_place()


func _current_target() -> Control:
	var hovered: Control = _find_target(get_viewport().gui_get_hovered_control())
	if hovered:
		return hovered
	
	var focused: Control = _find_target(get_viewport().gui_get_focus_owner())
	return focused if focused and focused.get_meta(FOCUS_META, true) else null


func _find_target(control: Control) -> Control:
	var current: Node = control
	while current is Control:
		if not get_text(current).is_empty() and (current as Control).is_visible_in_tree():
			return current
		current = current.get_parent()
	
	return null


func _show(slide_in: bool) -> void:
	_shown = true
	label.text = get_text(_target)
	bubble.reset_size()
	root.visible = true
	_place()
	_animate(Color.WHITE)
	_slide = _direction() * -slide if slide_in else Vector2.ZERO
	_tween.tween_property(self, ^"_slide", Vector2.ZERO, _duration())


func _hide() -> void:
	if not _shown:
		return
	
	_shown = false
	_animate(Color.TRANSPARENT).finished.connect(func() -> void:
		if not _shown:
			root.visible = false)


func _animate(target: Color) -> Tween:
	if _tween and _tween.is_valid():
		_tween.kill()
	
	_tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(root, ^"modulate", target, _duration())
	_tween.tween_method(_set_fade, root.modulate.a, target.a, _duration())
	return _tween


func _set_fade(weight: float) -> void:
	var blur: float = GDSS.get_global_var("blur_amount", 5.0)
	for panel: Control in [bubble, arrow]:
		GDSS.set_instance_var(panel, "tooltip_blur", blur * weight)
		GDSS.set_instance_var(panel, "tooltip_tint", tint * weight)


func _duration() -> float:
	return fade_duration if Settings.ui.animations.current_value else 0.0


func _place() -> void:
	var anchor: Rect2 = _target.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, _target.size)
	var size: Vector2 = bubble.size
	var screen: Rect2 = root.get_viewport_rect().grow(-margin)
	var mode: Placement = _target.get_meta(MODE_META, Placement.AUTO)
	if mode == Placement.AUTO:
		mode = AUTO_ORDER.front()
		for candidate: Placement in AUTO_ORDER:
			if screen.encloses(Rect2(_bubble_position(candidate, anchor, size), size)):
				mode = candidate
				break
	
	_mode = mode
	var position: Vector2 = _bubble_position(mode, anchor, size).clamp(screen.position, screen.end - size).round()
	bubble.position = position + _slide
	
	var vertical: bool = mode == Placement.UNDER or mode == Placement.ABOVE
	var arrow_size: Vector2 = Vector2(ARROW_WIDTH, ARROW_LENGTH) if vertical else Vector2(ARROW_LENGTH, ARROW_WIDTH)
	var inset: float = ARROW_WIDTH
	var center: Vector2 = anchor.get_center()
	var tip: Vector2 = center
	match mode:
		Placement.UNDER:
			tip = Vector2(clampf(center.x, position.x + inset, position.x + size.x - inset), position.y - ARROW_LENGTH / 2.0 + overlap)
		Placement.ABOVE:
			tip = Vector2(clampf(center.x, position.x + inset, position.x + size.x - inset), position.y + size.y + ARROW_LENGTH / 2.0 - overlap)
		Placement.RIGHT:
			tip = Vector2(position.x - ARROW_LENGTH / 2.0 + overlap, clampf(center.y, position.y + inset, position.y + size.y - inset))
		Placement.LEFT:
			tip = Vector2(position.x + size.x + ARROW_LENGTH / 2.0 - overlap, clampf(center.y, position.y + inset, position.y + size.y - inset))
	
	var arrow_class: String = ARROW_CLASSES.get(mode)
	if not GDSS.get_classes(arrow).has(arrow_class):
		GDSS.set_classes(arrow, PackedStringArray([arrow_class]))
	arrow.size = arrow_size
	arrow.position = (tip - arrow_size / 2.0).round() + _slide


func _bubble_position(mode: Placement, anchor: Rect2, size: Vector2) -> Vector2:
	var reach: float = ARROW_LENGTH + gap
	match mode:
		Placement.ABOVE:
			return Vector2(anchor.get_center().x - size.x / 2.0, anchor.position.y - reach - size.y)
		Placement.RIGHT:
			return Vector2(anchor.end.x + reach, anchor.get_center().y - size.y / 2.0)
		Placement.LEFT:
			return Vector2(anchor.position.x - reach - size.x, anchor.get_center().y - size.y / 2.0)
	
	return Vector2(anchor.get_center().x - size.x / 2.0, anchor.end.y + reach)


func _direction() -> Vector2:
	match _mode:
		Placement.ABOVE:
			return Vector2.DOWN
		Placement.RIGHT:
			return Vector2.LEFT
		Placement.LEFT:
			return Vector2.RIGHT
	
	return Vector2.UP
