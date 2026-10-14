class_name LDHandleStyle
extends Resource

enum Shape {
	CIRCLE,
	SQUARE,
	DIAMOND,
	BAR,
}

enum HandleState {
	NORMAL,
	HOVER,
	PRESSED,
	DISABLED,
}

@export var shape: Shape = Shape.CIRCLE
@export var size: Vector2 = Vector2(5.0, 5.0)
@export var grab_radius: float = 12.0
@export var outline_width: float = 2.0
@export var corner_radius: float = 2.0
@export_group("Normal")
@export var fill: Color = Color.WHITE
@export var outline: Color = Color("6496ed")
@export var texture: Texture2D
@export_group("Hover")
@export var hover_fill: Color = Color("6496ed")
@export var hover_outline: Color = Color.WHITE
@export var hover_texture: Texture2D
@export var hover_scale: float = 1.3
@export_group("Pressed")
@export var pressed_fill: Color = Color("6496ed")
@export var pressed_outline: Color = Color.WHITE
@export var pressed_texture: Texture2D
@export var pressed_scale: float = 1.15
@export_group("Disabled")
@export var disabled_fill: Color = Color(0.5, 0.5, 0.55, 0.6)
@export var disabled_outline: Color = Color(0.1, 0.16, 0.25, 0.6)


func get_fill(state: HandleState) -> Color:
	return [fill, hover_fill, pressed_fill, disabled_fill].get(state)


func get_outline(state: HandleState) -> Color:
	return [outline, hover_outline, pressed_outline, disabled_outline].get(state)


func get_scale(state: HandleState) -> float:
	return [1.0, hover_scale, pressed_scale, 1.0].get(state)


func get_texture(state: HandleState) -> Texture2D:
	var fallbacks: Array[Texture2D] = [texture, hover_texture if hover_texture else texture, pressed_texture if pressed_texture else hover_texture if hover_texture else texture, texture]
	return fallbacks.get(state)
