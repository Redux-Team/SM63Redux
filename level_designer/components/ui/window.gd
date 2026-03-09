class_name LDWindow
extends PanelContainer


@export var content: PackedScene
## Closes when the "back" input event is pressed.
@export var close_on_back_input: bool = false
@export var play_open_sfx: bool = false
@export var play_close_sfx: bool = true
@export_group("Internal")
@export var _content_container: PanelContainer

var _content_ref: Node


func _ready() -> void:
	for c: Node in _content_container.get_children(): c.queue_free()
	if content:
		_content_ref = content.instantiate()
		_content_container.add_child(_content_ref)


func _input(event: InputEvent) -> void:
	if close_on_back_input and event.is_action_pressed("_ui_back"):
		self.hide()

@warning_ignore("native_method_override")
func show() -> void:
	if play_open_sfx:
		SFX.play(SFX.UI_CONFIRM)
	scale = Vector2(0.6, 0.6)
	modulate = Color.TRANSPARENT
	
	
	var tween: Tween = create_tween().set_parallel()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUINT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.15)
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	
	visible = true
	
	if _content_ref.has_method(&"_on_show"):
		_content_ref.call(&"_on_show")

@warning_ignore("native_method_override")
func hide() -> void:
	if play_close_sfx:
		SFX.play(SFX.UI_BACK)
	scale = Vector2(1.0, 1.0)
	modulate = Color.WHITE
	
	var tween: Tween = create_tween().set_parallel()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUINT)
	tween.tween_property(self, "scale", Vector2(0.6, 0.6), 0.15)
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.15)
	
	await tween.finished
	visible = false
	
	if _content_ref.has_method(&"_on_hide"):
		_content_ref.call(&"_on_hide")


func _on_close_button_pressed() -> void:
	self.hide()
