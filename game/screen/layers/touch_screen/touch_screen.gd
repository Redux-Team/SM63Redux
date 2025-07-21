class_name TouchScreen
extends Control

const SNAP_THRESHOLD: float = 0.5

@export var preview: bool = false:
	set(p):
		for button: TouchButton in buttons:
			button.preview_mode = p
		preview = p

@export var buttons: Array[TouchButton]
@export var preview_bg: ColorRect
@export var snap_lines_display: Control


func _ready() -> void:
	if preview:
		for button: TouchButton in buttons:
			button.preview_mode = button.allow_preview
			button.visible = button.preview_mode
			button.moved.connect(_on_button_moved)
			
			button.setup()
			button.drag_started.connect(button.move_to_front)
			button.drag_ended.connect(func() -> void:
				snap_lines_display.set_snap_lines()
			)
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
	for button: TouchButton in buttons:
		positions.set(button.input_event, button.position)
	return positions


func assign_positions(positions: Dictionary[StringName, Vector2]) -> void:
	for button: TouchButton in buttons:
		var pos: Vector2 = positions.get(button.input_event, Vector2.ZERO)
		if pos:
			button.position = pos


func _on_button_moved(button: TouchButton) -> void:
	if not button.visible:
		return
	
	var snap_lines: Array[Vector2] = []
	var snapped: bool = false
	var current_rect: Rect2 = button.get_global_rect()
	var current_center: Vector2 = current_rect.get_center()
	var snap_position: Vector2 = button.global_position
	
	for other_button: TouchButton in buttons:
		if other_button == button or not other_button.visible:
			continue
		
		var other_rect: Rect2 = other_button.get_global_rect()
		var other_center: Vector2 = other_rect.get_center()
		
		var center_dx: float = abs(current_center.x - other_center.x)
		var center_dy: float = abs(current_center.y - other_center.y)
		
		if center_dx <= SNAP_THRESHOLD:
			snap_position.x = other_button.global_position.x
			var snap_x: float = other_center.x
			snap_lines.append(Vector2(snap_x, current_center.y))
			snap_lines.append(Vector2(snap_x, other_center.y))
			snapped = true
		
		if center_dy <= SNAP_THRESHOLD:
			snap_position.y = other_button.global_position.y
			var snap_y: float = other_center.y
			snap_lines.append(Vector2(current_center.x, snap_y))
			snap_lines.append(Vector2(other_center.x, snap_y))
			snapped = true
		
		var left_edge_distance: float = abs(current_rect.position.x - other_rect.end.x)
		var right_edge_distance: float = abs(current_rect.end.x - other_rect.position.x)
		var top_edge_distance: float = abs(current_rect.position.y - other_rect.end.y)
		var bottom_edge_distance: float = abs(current_rect.end.y - other_rect.position.y)
		
		var vertical_overlap: bool = not (current_rect.end.y < other_rect.position.y or current_rect.position.y > other_rect.end.y)
		var horizontal_overlap: bool = not (current_rect.end.x < other_rect.position.x or current_rect.position.x > other_rect.end.x)
		
		if vertical_overlap and left_edge_distance <= SNAP_THRESHOLD:
			snap_position.x = other_rect.end.x
			snap_lines.append(Vector2(other_rect.end.x, max(current_rect.position.y, other_rect.position.y)))
			snap_lines.append(Vector2(other_rect.end.x, min(current_rect.end.y, other_rect.end.y)))
			snapped = true
		
		if vertical_overlap and right_edge_distance <= SNAP_THRESHOLD:
			snap_position.x = other_rect.position.x - current_rect.size.x
			snap_lines.append(Vector2(other_rect.position.x, max(current_rect.position.y, other_rect.position.y)))
			snap_lines.append(Vector2(other_rect.position.x, min(current_rect.end.y, other_rect.end.y)))
			snapped = true
		
		if horizontal_overlap and top_edge_distance <= SNAP_THRESHOLD:
			snap_position.y = other_rect.end.y
			snap_lines.append(Vector2(max(current_rect.position.x, other_rect.position.x), other_rect.end.y))
			snap_lines.append(Vector2(min(current_rect.end.x, other_rect.end.x), other_rect.end.y))
			snapped = true
		
		if horizontal_overlap and bottom_edge_distance <= SNAP_THRESHOLD:
			snap_position.y = other_rect.position.y - current_rect.size.y
			snap_lines.append(Vector2(max(current_rect.position.x, other_rect.position.x), other_rect.position.y))
			snap_lines.append(Vector2(min(current_rect.end.x, other_rect.end.x), other_rect.position.y))
			snapped = true
	
	if snapped:
		button.global_position = snap_position
	
	if snap_lines_display and snap_lines_display.has_method("set_snap_lines"):
		snap_lines_display.set_snap_lines(snap_lines)
