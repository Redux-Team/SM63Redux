class_name DraggableItem
extends Control

@export var strict_bounds: bool = true

var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO


func _ready():
	gui_input.connect(_on_interaction_gui_input)


func _on_interaction_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			is_dragging = true
			drag_offset = event.position - global_position
			grab_focus()
		else:
			is_dragging = false
			release_focus()
	
	elif event is InputEventScreenDrag:
		if is_dragging:
			global_position = event.position - drag_offset
			if strict_bounds:
				_clamp_to_parent_bounds()
	
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_offset = event.global_position - global_position
			else:
				is_dragging = false
	
	elif event is InputEventMouseMotion:
		if is_dragging:
			global_position = event.global_position - drag_offset
			if strict_bounds:
				_clamp_to_parent_bounds()


func _clamp_to_parent_bounds():
	if get_parent() is Control:
		var parent_rect = get_parent().get_rect()
		var my_rect = get_rect()
		
		position.x = clamp(position.x, 0, parent_rect.size.x - my_rect.size.x)
		position.y = clamp(position.y, 0, parent_rect.size.y - my_rect.size.y)
