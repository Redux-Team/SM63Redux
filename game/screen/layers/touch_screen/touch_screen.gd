class_name TouchScreen
extends Control

@export var preview: bool = false:
	set(p):
		for button: TouchButton in buttons:
			button.preview_mode = p
		preview = p
@export var buttons: Array[TouchButton]
@export var preview_bg: ColorRect


func _ready() -> void:
	if preview:
		for button: TouchButton in buttons:
			button.preview_mode = button.allow_preview
			button.visible = button.preview_mode
			
			button.setup()
			button.drag_started.connect(button.move_to_front)
	else:
		for button: TouchButton in buttons:
			button.show()
		preview_bg.hide()


func apply_scale(amount: float) -> void:
	for button: TouchButton in buttons:
		if button.is_static:
			return
		
		button.scale = Vector2(amount, amount) * 2


func apply_opacity(amount: float) -> void:
	for button: TouchButton in buttons:
		if button.is_static:
			return
		button.modulate.a = amount / 100


func get_positions() -> Dictionary[StringName, Vector2]:
	var positions: Dictionary[StringName, Vector2] = {}
	for button in buttons:
		positions.set(button.input_event, button.position)
	return positions


func assign_positions(positions: Dictionary[StringName, Vector2]) -> void:
	for button in buttons:
		var pos: Vector2 = positions.get(button.input_event, Vector2.ZERO)
		if pos:
			button.position = pos
