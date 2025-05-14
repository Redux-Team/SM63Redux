@tool
class_name ResizableLabel extends Label

enum ResizeMode {
	STATIC,
	ASPECT,
}

@export var font_size: int = 16:
	set(fs):
		add_theme_font_size_override(&"font_size", fs)
		font_size = fs

@export var outline_size: int = 0:
	set(os):
		add_theme_constant_override(&"outline_size", os)
		outline_size = os

@export var outline_color: Color = Color.BLACK:
	set(oc):
		add_theme_color_override(&"font_outline_color", oc)
		outline_color = oc

@onready var original_size: Vector2 = size

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and not Engine.is_editor_hint():
		_update_font_size_aspect()

func _update_font_size_aspect() -> void:
	if original_size.x <= 0.1 or original_size.y <= 0.1:
		return
	
	var current_size = size
	
	var scale_x: float = current_size.x / original_size.x
	var scale_y: float = current_size.y / original_size.y
	var font_scale: float = min(scale_x, scale_y) # Maintain aspect ratio
	
	# Resize threshold (to prevent resizing having a seizure w/ really small changes)
	if abs((font_size * font_scale) - get_theme_font_size(&"font_size")) < 0.5:
		return
	
	var new_font_size = int(font_size * font_scale)
	var new_outline_size = int(outline_size * font_scale)
	
	add_theme_font_size_override(&"font_size", new_font_size)
	add_theme_constant_override(&"outline_size", new_outline_size)
