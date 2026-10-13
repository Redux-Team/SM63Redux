class_name LDGamepadCursor
extends LDComponent

@export var canvas: Control
@export var speed: float = 360.0
@export var color: Color = Color("3da4ff")
@export var radius: float = 5.0

var _active: bool = false
var _position: Vector2


func _setup() -> void:
	canvas.draw.connect(_on_draw)
	_position = canvas.get_viewport_rect().get_center()


func _input(event: InputEvent) -> void:
	var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
	if not _active and (event is InputEventJoypadButton or (motion and absf(motion.axis_value) > 0.5)):
		_set_active(true)
	elif event is InputEventMouseMotion and _active and not (event as InputEventMouseMotion).position.is_equal_approx(_position):
		_set_active(false)
	
	if _active and event.is_action(&"ld_click") and not event.is_echo():
		_click(event.is_pressed())
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _active:
		return
	
	var direction: Vector2 = Input.get_vector(&"ld_cursor_left", &"ld_cursor_right", &"ld_cursor_up", &"ld_cursor_down")
	if direction.is_zero_approx():
		return
	
	_position = (_position + direction * speed * delta).clamp(Vector2.ZERO, canvas.get_viewport_rect().size)
	get_viewport().warp_mouse(_position)
	canvas.queue_redraw()


func _click(pressed: bool) -> void:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	click.pressed = pressed
	click.position = _position
	click.global_position = _position
	Input.parse_input_event(click)


func _set_active(active: bool) -> void:
	_active = active
	if active:
		_position = canvas.get_viewport().get_mouse_position()
	canvas.queue_redraw()


func _on_draw() -> void:
	if not _active:
		return
	
	canvas.draw_circle(_position, radius + 1.5, Color(0.0, 0.0, 0.0, 0.5))
	canvas.draw_circle(_position, radius, color)
	canvas.draw_circle(_position, radius * 0.4, Color.WHITE)
