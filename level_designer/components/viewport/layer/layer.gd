class_name LDLayer
extends CanvasGroup


@export var layer_index: int = 0
@export var parallax_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	set_process(parallax_scale != Vector2.ONE)


func _process(_delta: float) -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam:
		position = cam.global_position * (Vector2.ONE - parallax_scale)
