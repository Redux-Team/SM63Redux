class_name ForceDisplay
extends Control

@export var player: Player
@export var force_scale: float = 0.02
@export var velocity_scale: float = 0.15
@export var velocity_color: Color = Color(0.36, 0.76, 0.9)
@export var colors: Dictionary[StringName, Color] = {
	&"lift": Color(0.37, 0.83, 0.58),
	&"drag": Color(1.0, 0.42, 0.51),
	&"gravity": Color(0.71, 0.61, 1.0),
	&"thrust": Color(1.0, 0.75, 0.3),
	&"polar": Color(1.0, 0.75, 0.3),
}
@export var default_color: Color = Color.WHITE
@export var line_width: float = 1.5
@export var head_size: float = 4.0
@export var font_size: int = 8


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not player:
		return
	
	_draw_arrow(player.velocity * velocity_scale, velocity_color, &"velocity")
	for force_name: StringName in player.debug_forces:
		_draw_arrow(
				player.debug_forces[force_name] * force_scale,
				colors.get(force_name, default_color),
				force_name,
		)


func _draw_arrow(vector: Vector2, color: Color, label: StringName) -> void:
	if vector.length() < 1.0:
		return
	
	var direction: Vector2 = vector.normalized()
	draw_line(Vector2.ZERO, vector, color, line_width)
	draw_colored_polygon(
			PackedVector2Array(
					[
						vector,
						vector - direction.rotated(0.45) * head_size,
						vector - direction.rotated(-0.45) * head_size,
					]
			),
			color,
	)
	draw_string(
			ThemeDB.fallback_font,
			vector + direction * 3.0,
			String(label),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			color,
	)
