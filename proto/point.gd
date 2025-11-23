class_name LDCurvePoint
extends TestDraggable

signal delete_request(ref: LDCurvePoint)

@export var in_handle: TestDraggable
@export var out_handle: TestDraggable

var hovering: bool = false
var tangent_angle: float = 0.0


func prep(slope: float) -> void:
	tangent_angle = slope
	var handle_length: float = 80.0
	in_handle.position = Vector2.from_angle(tangent_angle + (PI / 2.0)) * handle_length
	out_handle.position = Vector2.from_angle(tangent_angle + ((3 * PI) / 2.0)) * handle_length


func _ready() -> void:
	in_handle.moved.connect(_on_in_handle_moved)
	out_handle.moved.connect(_on_out_handle_moved)


func _on_in_handle_moved() -> void:
	var angle: float = in_handle.position.angle()
	var in_len: float = in_handle.position.length()
	var out_len: float = out_handle.position.length()
	
	if Input.is_key_pressed(KEY_ALT):
		tangent_angle = angle
		return
	
	if Input.is_key_pressed(KEY_SHIFT):
		out_handle.position = Vector2.from_angle(angle + PI) * out_len
	else:
		out_handle.position = Vector2.from_angle(angle + PI) * in_len
	
	tangent_angle = angle


func _on_out_handle_moved() -> void:
	var angle: float = out_handle.position.angle()
	var out_len: float = out_handle.position.length()
	var in_len: float = in_handle.position.length()
	
	if Input.is_key_pressed(KEY_ALT):
		tangent_angle = angle
		return
	
	if Input.is_key_pressed(KEY_SHIFT):
		in_handle.position = Vector2.from_angle(angle + PI) * in_len
	else:
		in_handle.position = Vector2.from_angle(angle + PI) * out_len
	
	tangent_angle = angle


func _on_gui_input(event: InputEvent) -> void:
	super(event)
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			delete_request.emit(self)


func _input(event: InputEvent) -> void:
	if hovering and event is InputEventKey and event.keycode == KEY_C and event.pressed:
		var was_visible: bool = in_handle.visible
		in_handle.visible = not was_visible
		out_handle.visible = not was_visible
		
		if not was_visible:
			var parent: Node = get_parent()
			var point_index: int = parent.points.find(self)
			if point_index != -1:
				var perp_angle: float = parent.calculate_tangent_angle(point_index)
				prep(perp_angle)


func _on_mouse_entered() -> void:
	hovering = true


func _on_mouse_exited() -> void:
	hovering = false
