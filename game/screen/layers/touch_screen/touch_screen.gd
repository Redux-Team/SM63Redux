class_name TouchScreen
extends Control

const TOUCH_SCREEN_INSTANCE = preload("uid://l87i6yic73um")

@export var preview: bool = false:
	set(p):
		for button: TouchButton in buttons:
			button.preview_mode = p
		
		preview = p
@export var buttons: Array[TouchButton]

@export var preview_bg: ColorRect
@export var left_rect: ColorRect 
@export var right_rect: ColorRect


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


func get_positions() -> Dictionary[StringName, Dictionary]:
	var positions: Dictionary[StringName, Dictionary] = {}
	for button in buttons:
		positions.set(button.input_event, {
			"anchor_left": button.anchor_left,
			"anchor_top": button.anchor_top,
			"anchor_right": button.anchor_right,
			"anchor_bottom": button.anchor_bottom,
			"offset_left": button.offset_left,
			"offset_top": button.offset_top,
			"offset_right": button.offset_right,
			"offset_bottom": button.offset_bottom
		})
	return positions



func assign_positions(positions: Dictionary[StringName, Dictionary]) -> void:
	for button in buttons:
		var data: Dictionary = positions.get(button.input_event)
		if data:
			button.anchor_left = data.anchor_left
			button.anchor_top = data.anchor_top
			button.anchor_right = data.anchor_right
			button.anchor_bottom = data.anchor_bottom

			button.offset_left = data.offset_left
			button.offset_top = data.offset_top
			button.offset_right = data.offset_right
			button.offset_bottom = data.offset_bottom




func _on_button_move(button: TouchButton):
	if (button.position.x + (button.size.x * button.scale.x / 2)) < size.x / 2.0:
		left_rect.show()
		right_rect.hide()
	else:
		left_rect.hide()
		right_rect.show()
