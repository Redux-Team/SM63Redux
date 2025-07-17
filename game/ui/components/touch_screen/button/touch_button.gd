@tool
class_name TouchButton
extends Control

signal moved(ref: TouchButton)
signal drag_started
signal drag_ended

@export var base_scale: float = 1.0
@export var base_opacity: float = 1.0

@export var allow_preview: bool = true
@export var is_static: bool = false
@export_storage var preview_mode: bool = true
@export var preview_parent_size: Vector2 = Vector2.ONE

@export_group("Internal")
@export var button_node: TouchScreenButton
@export var drag_capture: Control
@export var input_config: InputConfig


var input_event: StringName:
	set(ie):
		input_event = ie
		
		pivot_offset = size / 2
		
		if !button_node or !input_config.button_map or !ie:
			return
		
		button_node.texture_normal = input_config.button_map.get(ie).normal_texture
		button_node.texture_pressed = input_config.button_map.get(ie).pressed_texture
		
		if button_node.texture_normal:
			size = button_node.texture_normal.get_size()
		
		button_node.action = input_event

var _dragging: bool = false
var _drag_offset: Vector2


func _get_property_list() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	
	# Add a category at the top
	list.append({
		"name": "Input",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_CATEGORY
	})
	
	if input_config != null:
		var scheme = input_config.get_active_control_scheme()
		if scheme != null:
			var inputs: Array[String] = scheme.get_inputs_string(true)
			
			list.append({
				"name": "input_event",
				"type": TYPE_STRING,
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": ",".join(inputs),
				"usage": PROPERTY_USAGE_DEFAULT
			})
	
	return list


func _ready() -> void:
	if drag_capture.gui_input.is_connected(_on_drag_capture_input):
		drag_capture.gui_input.disconnect(_on_drag_capture_input)
	drag_capture.gui_input.connect(_on_drag_capture_input)
	
	if preview_mode:
		button_node.passby_press = false
	else:
		button_node.passby_press = true
	
	update_visual()


func update_visual() -> void:
	button_node.scale = Vector2.ONE * base_scale
	button_node.modulate.a = base_opacity
	drag_capture.visible = preview_mode


func set_normalized_position(pos: Vector2) -> void:
	position = pos * preview_parent_size


func get_normalized_position() -> Vector2:
	if preview_parent_size == Vector2.ZERO:
		return Vector2.ZERO
	
	return position / preview_parent_size


func _on_drag_capture_input(event: InputEvent) -> void:
	if not preview_mode or is_static:
		return
	
	if event is InputEventScreenTouch and event.pressed:
		_dragging = true
		_drag_offset = drag_capture.get_global_mouse_position() - global_position
		drag_started.emit()
	
	elif event is InputEventScreenTouch and not event.pressed:
		_dragging = false
		drag_ended.emit()
	
	elif event is InputEventScreenDrag:
		if _dragging:
			position += event.relative * scale
			moved.emit(self)
			_clamp_bounds()


func _clamp_bounds() -> void:
	var parent: Control = get_parent_control()
	
	if not parent:
		return
	

	var parent_size = parent.size
	var effective_size = size * scale
	
	var min_pos = effective_size * 0.5
	var max_pos = parent_size - (effective_size * 0.5)

	if parent_size == Vector2.ZERO:
		return
	
	position.x = clamp(position.x, min_pos.x, max_pos.x)
	position.y = clamp(position.y, min_pos.y, max_pos.y)
