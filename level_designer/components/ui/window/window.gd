class_name LDWindow
extends CanvasLayer

signal popped_in
signal popped_out

@export var title: String:
	set(t):
		title = t
		if _title_label:
			_title_label.text = t

@export var content: PackedScene

## Closes when the "back" input event is pressed.
@export var close_on_back_input: bool = false

@export var window_scale: Vector2 = Vector2.ONE

@export_group("Pop In", "pop_in")
@export var pop_in_sfx: bool = false
@export var pop_in_centered: bool = true

@export_group("Pop Out", "pop_out")
@export var pop_out_sfx: bool = true
@export var pop_out_free: bool = false

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

var _content_ref: Node
var _tween: Tween
var _backdrop_alpha: float = 0.0:
	set(v):
		_backdrop_alpha = v
		if _backdrop and _backdrop.material:
			var mat: ShaderMaterial = _backdrop.material as ShaderMaterial
			mat.set_shader_parameter(&"tint", Color(backdrop_color.r, backdrop_color.g, backdrop_color.b, backdrop_color.a * v))
			mat.set_shader_parameter(&"blur", backdrop_blur * v)
var _popping_in: bool = false
var _popping_out: bool = false


static func create(control: Control) -> LDWindow:
	var window: LDWindow = preload("uid://bbf6gei1bmu46").instantiate()
	window.assign_control(control)
	return window


func _init() -> void:
	visible = false


func _ready() -> void:
	if content:
		assign_control(content.instantiate())
	_title_label.text = title
	if title.is_empty():
		_title_label.hide()
	_setup_backdrop()


func _input(event: InputEvent) -> void:
	if close_on_back_input and event.is_action_pressed("_ui_back"):
		popout()


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


@warning_ignore("native_method_override")
func popin() -> void:
	if _popping_in:
		return
	_popping_in = true
	
	if _tween:
		_tween.kill()
	
	if pop_in_sfx:
		SFX.play(SFX.LD_OPEN)
	
	if is_instance_valid(_content_ref) and _content_ref.has_method(&"_on_show"):
		_content_ref.call(&"_on_show")
	
	visible = true
	_panel.scale = Vector2(0.6, 0.6)
	_panel.modulate = Color.TRANSPARENT
	
	_panel.size = Vector2.ZERO
	await get_tree().process_frame
	_panel.size = Vector2.ZERO
	await get_tree().process_frame
	
	if pop_in_centered:
		_center_in_viewport()
	
	if backdrop_enabled and _backdrop:
		_backdrop_alpha = 0.0
		_backdrop.visible = true
	
	_tween = create_tween().set_parallel()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_QUINT)
	_tween.tween_property(_panel, "scale", window_scale, 0.15)
	_tween.tween_property(_panel, "modulate", Color.WHITE, 0.15)
	if backdrop_enabled and _backdrop:
		_tween.tween_property(self, "_backdrop_alpha", 1.0, 0.3)
	
	await _tween.finished
	_popping_in = false
	popped_in.emit()


@warning_ignore("native_method_override")
func popout() -> void:
	if not visible or _popping_out:
		return
	_popping_out = true
	
	if pop_out_sfx:
		SFX.play(SFX.LD_CLOSE)
	
	_panel.scale = window_scale
	_panel.modulate = Color.WHITE
	
	_tween = create_tween().set_parallel()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_QUINT)
	_tween.tween_property(_panel, "scale", Vector2(0.6, 0.6), 0.15)
	_tween.tween_property(_panel, "modulate", Color.TRANSPARENT, 0.15)
	if backdrop_enabled and _backdrop:
		_tween.tween_property(self, "_backdrop_alpha", 0.0, 0.15)
	
	await _tween.finished
	
	_popping_out = false
	visible = false
	if backdrop_enabled and _backdrop:
		_backdrop.visible = false
	
	popped_out.emit()
	
	if pop_out_free:
		queue_free()
		return
	
	if is_instance_valid(_content_ref) and _content_ref.has_method(&"_on_hide"):
		_content_ref.call(&"_on_hide")


func assign_control(control: Control) -> void:
	if not control:
		return
	for c: Node in _content_container.get_children():
		c.queue_free()
	if control.get_parent():
		control.reparent(_content_container)
	else:
		_content_container.add_child(control)
	_content_ref = control


func get_content_ref() -> Control:
	return _content_ref


func _center_in_viewport() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_panel.position = ((viewport_size - _panel.size) / 2.0).clamp(Vector2.ZERO, viewport_size - _panel.size)


func _on_close_button_pressed() -> void:
	popout()
