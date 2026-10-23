class_name CoinCounter
extends HBoxContainer

@export var label: RichTextLabel
@export var requires_total: bool = false
@export var total_font_size: int = 24
@export var flash_color: Color = Color.WHITE
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var count_time: float = 0.15
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var flash_time: float = 0.1

var _count: int = 0:
	set(value):
		_count = value
		label.text = (
				str(value)
				if _total <= 0
				else "%d[font_size=%d]/%d" % [value, total_font_size, _total]
		)
var _total: int = 0
var _count_tween: Tween
var _flash_tween: Tween


func _ready() -> void:
	visible = not requires_total


func set_count(count: int, total: int = 0) -> void:
	_total = total
	visible = total > 0 or not requires_total
	if _count_tween:
		_count_tween.kill()
	_count_tween = create_tween()
	_count_tween.tween_property(self, ^"_count", count, count_time)
	
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_flash_tween.tween_property(label, ^"modulate", flash_color, flash_time)
	_flash_tween.tween_property(label, ^"modulate", Color.WHITE, flash_time)
