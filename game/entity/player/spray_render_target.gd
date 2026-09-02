extends Sprite2D


@export var spray_viewport: SubViewport


var _last_viewport_size: Vector2i


var camera: Camera2D:
	get:
		return LevelCamera.get_camera()


func _ready() -> void:
	_last_viewport_size = get_window().size
	_refresh()


func _process(_delta: float) -> void:
	var viewport_size: Vector2i = get_window().size
	if viewport_size != _last_viewport_size:
		_refresh()
	
	_last_viewport_size = viewport_size
	spray_viewport.canvas_transform = get_canvas_transform()
	
	scale = Vector2(1.0, 1.0) / camera.get_canvas_transform().get_scale()
	position = (Vector2(spray_viewport.size) / 2.0 - camera.get_canvas_transform().origin) * scale
	material.set_shader_parameter("zoom", camera.zoom.x / 2.0)


func _refresh() -> void:
	spray_viewport.size = get_window().size
	texture = spray_viewport.get_texture()
