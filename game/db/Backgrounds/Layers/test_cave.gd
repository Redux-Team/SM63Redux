extends LDBackgroundScene


@export var container: SubViewportContainer
@export var world_camera: Camera3D
@export var units_per_pixel: float = 0.02


var _home_position: Vector3
var _home_basis: Basis
var _origin: Vector2 = Vector2.ZERO
var _has_origin: bool = false


func _ready() -> void:
	_home_position = world_camera.position
	_home_basis = world_camera.basis
	get_viewport().size_changed.connect(_fit_to_screen)
	camera_synced.connect(_on_camera_synced)
	_fit_to_screen()


func _fit_to_screen() -> void:
	var rect: Rect2 = get_viewport_rect()
	container.size = rect.size
	container.global_position = rect.position


func _on_camera_synced(center: Vector2, _zoom: Vector2) -> void:
	if not _has_origin:
		_origin = center
		_has_origin = true
	var offset: Vector2 = (center - _origin) * units_per_pixel
	world_camera.position = _home_position + _home_basis.x * offset.x - _home_basis.y * offset.y
