class_name LDWaveformView
extends Control


signal seek_requested(fraction: float)


@export var bar_count: int = 180
@export var played_color: Color = Color(0.43, 0.74, 1.0)
@export var unplayed_color: Color = Color(0.43, 0.74, 1.0, 0.28)
@export var background_color: Color = Color(0.0, 0.0, 0.0, 0.22)


var _bars: PackedFloat32Array = PackedFloat32Array()
var _progress: float = 0.0


func _ready() -> void:
	_bars.resize(bar_count)


func clear_bars() -> void:
	for i: int in bar_count:
		_bars.set(i, 0.0)
	_progress = 0.0
	queue_redraw()


func load_bars(values: PackedFloat32Array) -> void:
	_bars = values.duplicate()
	if _bars.size() != bar_count:
		_bars.resize(bar_count)
	queue_redraw()


func get_bars() -> PackedFloat32Array:
	return _bars.duplicate()


func write_peak(fraction: float, value: float) -> void:
	var idx: int = clampi(int(fraction * float(bar_count)), 0, bar_count - 1)
	if value > _bars.get(idx):
		_bars.set(idx, value)
		queue_redraw()


func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed and size.x > 0.0:
			seek_requested.emit(clampf(button.position.x / size.x, 0.0, 1.0))
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_LEFT and size.x > 0.0:
			seek_requested.emit(clampf(motion.position.x / size.x, 0.0, 1.0))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background_color)
	var mid: float = size.y * 0.5
	var bar_width: float = size.x / float(bar_count)
	var amplitude: float = size.y * 0.5 - 1.0
	var played_until: float = _progress * float(bar_count)
	for i: int in bar_count:
		var value: float = clampf(_bars.get(i), 0.0, 1.0)
		var height: float = maxf(1.0, value * amplitude)
		var x: float = float(i) * bar_width
		var color: Color = played_color if float(i) <= played_until else unplayed_color
		draw_rect(Rect2(x, mid - height, maxf(1.0, bar_width - 1.0), height * 2.0), color)
	var head_x: float = clampf(_progress, 0.0, 1.0) * size.x
	draw_line(Vector2(head_x, 0.0), Vector2(head_x, size.y), played_color, 1.0)
