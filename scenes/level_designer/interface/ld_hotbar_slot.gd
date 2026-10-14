class_name LDHotbarSlot
extends Button

signal tapped(slot: LDHotbarSlot)
signal held(slot: LDHotbarSlot)
signal moved(from: int, to: int)

const HOLD_TIME: float = 0.55
const DRAG_KEY: String = "ld_hotbar_slot"

@export var ring_color: Color = Color("3da4ff")

var index: int = 0
var _hold: float = -1.0


func _ready() -> void:
	set_process(false)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)


func _process(delta: float) -> void:
	_hold += delta
	queue_redraw()
	if _hold >= HOLD_TIME:
		_stop_hold()
		held.emit(self)


func _draw() -> void:
	if _hold > 0.0:
		var radius: float = minf(size.x, size.y) / 2.0 - 2.0
		draw_arc(size / 2.0, radius, -PI / 2.0, -PI / 2.0 + TAU * _hold / HOLD_TIME, 32, ring_color, 2.0, true)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if icon == null:
		return null
	
	_stop_hold()
	var preview: TextureRect = TextureRect.new()
	preview.texture = icon
	preview.size = size
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	return {DRAG_KEY: index}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).has(DRAG_KEY)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	moved.emit((data as Dictionary).get(DRAG_KEY), index)


func _on_button_down() -> void:
	_hold = 0.0
	set_process(true)


func _on_button_up() -> void:
	if _hold >= 0.0:
		tapped.emit(self)
	_stop_hold()


func _stop_hold() -> void:
	_hold = -1.0
	set_process(false)
	queue_redraw()
