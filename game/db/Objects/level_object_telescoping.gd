class_name LevelObjectTelescoping
extends LevelObject


enum ExpandDirection {
	X,
	Y
}

@export var nine_patch: NinePatchRect
@export var collision_shape: CollisionShape2D
@export var expand_direction: ExpandDirection = ExpandDirection.X

var _initial_collision_size: Vector2
var _initial_nine_patch_size: Vector2

var t_size_x: int = 0
var t_size_y: int = 0


func _on_init() -> void:
	if collision_shape and collision_shape.shape is RectangleShape2D:
		_initial_collision_size = (collision_shape.shape as RectangleShape2D).size
	if nine_patch:
		_initial_nine_patch_size = nine_patch.size
	_apply_size(t_size_x if expand_direction == ExpandDirection.X else t_size_y)


func _apply_size(units: int) -> void:
	var is_x: bool = expand_direction == ExpandDirection.X
	
	var middle_seg: float = _get_middle_segment_size()
	var end_caps: float = _get_end_caps_size()
	var total: float = middle_seg * units + end_caps
	
	if nine_patch:
		nine_patch.size = Vector2(
			total if is_x else _initial_nine_patch_size.x,
			total if not is_x else _initial_nine_patch_size.y
		)
		nine_patch.position = -nine_patch.size / 2.0
	
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var shape: RectangleShape2D = collision_shape.shape 
		shape.size = Vector2(
			total if is_x else _initial_collision_size.x,
			total if not is_x else _initial_collision_size.y
		)


func _get_middle_segment_size() -> float:
	if not nine_patch or not nine_patch.texture:
		return 16.0
	var tex_size: float = nine_patch.texture.get_width() if expand_direction == ExpandDirection.X else nine_patch.texture.get_height()
	var margins: float = nine_patch.patch_margin_left + nine_patch.patch_margin_right if expand_direction == ExpandDirection.X else nine_patch.patch_margin_top + nine_patch.patch_margin_bottom
	return tex_size - margins


func _get_end_caps_size() -> float:
	if not nine_patch:
		return 16.0
	if expand_direction == ExpandDirection.X:
		return nine_patch.patch_margin_left + nine_patch.patch_margin_right
	return nine_patch.patch_margin_top + nine_patch.patch_margin_bottom
