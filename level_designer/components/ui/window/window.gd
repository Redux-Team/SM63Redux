class_name LDWindow
extends PanelContainer

signal popped_in
signal popped_out

@export var title: String:
	set(t):
		if _title_label:
			_title_label.text = t
		title = t
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
@export_group("Internal")
@export var _content_container: PanelContainer
@export var _title_label: Label

var _content_ref: Node


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


func _input(event: InputEvent) -> void:
	if close_on_back_input and event.is_action_pressed("_ui_back"):
		popout()

@warning_ignore("native_method_override")
func popin() -> void:
	if pop_in_sfx:
		SFX.play(SFX.UI_CONFIRM)
	
	scale = Vector2.ONE
	
	if pop_in_centered:
		position = (get_viewport().get_visible_rect().size / 2) - (size / 2)
	
	scale = Vector2(0.6, 0.6)
	modulate = Color.TRANSPARENT
	
	
	var tween: Tween = create_tween().set_parallel()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUINT)
	tween.tween_property(self, "scale", window_scale, 0.15)
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	
	visible = true
	
	if _content_ref.has_method(&"_on_show"):
		_content_ref.call(&"_on_show")
	
	size = Vector2.ZERO
	await get_tree().process_frame
	position = (get_viewport().get_visible_rect().size / 2) - (size / 2)
	
	popped_in.emit()

@warning_ignore("native_method_override")
func popout() -> void:
	if pop_out_sfx:
		SFX.play(SFX.UI_BACK)
	scale = window_scale
	modulate = Color.WHITE
	
	var tween: Tween = create_tween().set_parallel()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUINT)
	tween.tween_property(self, "scale", Vector2(0.6, 0.6), 0.15)
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.15)
	
	await tween.finished
	visible = false
	
	popped_out.emit()
	
	if pop_out_free:
		queue_free()
		return
	
	if is_instance_valid(_content_ref):
		if _content_ref.has_method(&"_on_hide"):
			_content_ref.call(&"_on_hide")


func assign_control(control: Control) -> void:
	if control:
		for c: Node in _content_container.get_children(): c.queue_free()
		if control.get_parent():
			control.reparent(_content_container)
		else:
			_content_container.add_child(control)
		_content_ref = control


func get_content_ref() -> Control:
	return _content_ref


func _on_close_button_pressed() -> void:
	popout()
