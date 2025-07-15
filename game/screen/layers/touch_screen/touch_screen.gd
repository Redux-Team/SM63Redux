class_name TouchScreen
extends Control

const TOUCH_SCREEN_INSTANCE = preload("uid://l87i6yic73um")

@export var preview: bool = false
@export var buttons: Array[TouchButton]

@export var preview_bg: ColorRect
@export var left_rect: ColorRect 
@export var right_rect: ColorRect

var positions: Dictionary[TouchButton, Vector2]


static func new_instance() -> TouchScreen:
	return TOUCH_SCREEN_INSTANCE.duplicate(true).instantiate()


func _ready() -> void:
	if preview:
		for button: TouchButton in buttons:
			button.preview_mode = button.allow_preview
			button.visible = button.preview_mode
			
			button.moved.connect(_on_button_move)
			
			button._ready()
			
			button.drag_ended.connect(func() -> void:
				left_rect.hide()
				right_rect.hide()
			)
			
			button.drag_started.connect(func() -> void:
				button.move_to_front()
			)
			
			positions.set(button, button.position)
	else:
		for button: TouchButton in buttons:
			button.show()
		preview_bg.hide()


func get_packed_scene() -> PackedScene:
	var packed_scene: PackedScene = PackedScene.new()
	packed_scene.pack(self)
	
	return packed_scene


func apply_scale(amount: float) -> void:
	for button: TouchButton in buttons:
		if button.is_static:
			return
		
		button.scale = Vector2(amount, amount)
		
		if preview:
			button.scale *= 1.25


func apply_opacity(amount: float) -> void:
	for button: TouchButton in buttons:
		if button.is_static:
			return
		button.modulate.a = amount / 100


func _on_button_move(button: TouchButton):
	if (button.position.x + (button.size.x * button.scale.x / 2)) < size.x / 2.0:
		left_rect.show()
		right_rect.hide()
		button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	else:
		left_rect.hide()
		right_rect.show()
		button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
