class_name LDWaveformView
extends Control


signal seek_requested(fraction: float)


@export var bin_count: int = 180
@export var played_color: Color = Color(0.43, 0.74, 1.0)
@export var unplayed_color: Color = Color(0.43, 0.74, 1.0, 0.28)
@export var background_color: Color = Color(0.0, 0.0, 0.0, 0.22)


var _bins: PackedFloat32Array = PackedFloat32Array()
var _progress: float = 0.0


func _ready() -> void:
	_bins.resize(bin_count)


func clear_bins() -> void:
	for i: int in bin_count:
		_bins.set(i, 0.0)
	_progress = 0.0
	queue_redraw()


func load_bins(values: PackedFloat32Array) -> void:
	_bins = values.duplicate()
	if _bins.size() != bin_count:
		_bins.resize(bin_count)
	queue_redraw()


func get_bins() -> PackedFloat32Array:
	return _bins.duplicate()


func write_peak(fraction: float, value: float) -> void:
	var idx: int = clampi(int(fraction * float(bin_count)), 0, bin_count - 1)
	if value > _bins.get(idx):
		_bins.set(idx, value)
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
	var bar_width: float = size.x / float(bin_count)
	var amplitude: float = size.y * 0.5 - 1.0
	var played_until: float = _progress * float(bin_count)
	for i: int in bin_count:
		var value: float = clampf(_bins.get(i), 0.0, 1.0)
		var height: float = maxf(1.0, value * amplitude)
		var x: float = float(i) * bar_width
		var color: Color = played_color if float(i) <= played_until else unplayed_color
		draw_rect(Rect2(x, mid - height, maxf(1.0, bar_width - 1.0), height * 2.0), color)
	var head_x: float = clampf(_progress, 0.0, 1.0) * size.x
	draw_line(Vector2(head_x, 0.0), Vector2(head_x, size.y), played_color, 1.0)
