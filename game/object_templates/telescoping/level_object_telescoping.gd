class_name LevelObjectTelescoping
extends LevelObject

@export var nine_patch: NinePatchRect
@export var collision_shapes: Array[CollisionShape2D]

var _initial_nine_patch_size: Vector2
var _collision_expand: Vector2 = Vector2.ZERO
var _collision_offset: Vector2 = Vector2.ZERO
var _collision_anchor: GameObject.CollisionAnchor = GameObject.CollisionAnchor.TOP
var _collision_collapsed: bool = false
var t_size_x: int = 0
var t_size_y: int = 0


func _on_init() -> void:
	if nine_patch:
		_initial_nine_patch_size = nine_patch.size
	
	_apply_size_x(t_size_x)
	_apply_size_y(t_size_y)
	_apply_collision()


func _is_x_telescoping() -> bool:
	if not nine_patch:
		return true
	return (nine_patch.patch_margin_left + nine_patch.patch_margin_right) > 0


func _is_y_telescoping() -> bool:
	if not nine_patch:
		return false
	return (nine_patch.patch_margin_top + nine_patch.patch_margin_bottom) > 0


func _get_anchor_offset(col_size: Vector2, visual_size: Vector2) -> Vector2:
	match _collision_anchor:
		GameObject.CollisionAnchor.TOP:
			# adding 2 to the y here since normally theres a padding of a transparent + outline pixel
			return Vector2(0.0, 2.0 + (-(visual_size.y - col_size.y) / 2.0))
		GameObject.CollisionAnchor.BOTTOM:
			return Vector2(0.0, (visual_size.y - col_size.y) / 2.0)
		GameObject.CollisionAnchor.LEFT:
			return Vector2(-(visual_size.x - col_size.x) / 2.0, 0.0)
		GameObject.CollisionAnchor.RIGHT:
			return Vector2((visual_size.x - col_size.x) / 2.0, 0.0)
	return Vector2.ZERO


func _apply_size_x(units: int) -> void:
	var total: float = _get_end_caps_size_x() + _get_middle_segment_size_x() * units
	
	if nine_patch:
		nine_patch.size.x = total
		nine_patch.position.x = -total / 2.0


func _apply_size_y(units: int) -> void:
	var total: float = _get_end_caps_size_y() + _get_middle_segment_size_y() * units
	
	if nine_patch:
		nine_patch.size.y = total
		nine_patch.position.y = -total / 2.0


func _apply_collision() -> void:
	var col_size: Vector2 = Vector2(
		0.0 if _collision_collapsed and not _is_x_telescoping() else _get_end_caps_size_x(_collision_expand.x) + _get_middle_segment_size_x() * t_size_x,
		0.0 if _collision_collapsed and not _is_y_telescoping() else _get_end_caps_size_y(_collision_expand.y) + _get_middle_segment_size_y() * t_size_y
	)
	var visual_size: Vector2 = nine_patch.size if nine_patch else Vector2.ZERO
	var anchor: Vector2 = _get_anchor_offset(col_size, visual_size)
	
	for i: int in collision_shapes.size():
		var col: CollisionShape2D = collision_shapes.get(i)
		if not col or not col.shape is RectangleShape2D:
			continue
		(col.shape as RectangleShape2D).size = col_size
		col.position = anchor + _collision_offset


func _get_middle_segment_size_x() -> float:
	if not nine_patch or not nine_patch.texture:
		return 16.0
	return maxf(float(nine_patch.texture.get_width() - nine_patch.patch_margin_left - nine_patch.patch_margin_right), 0.0)


func _get_middle_segment_size_y() -> float:
	if not nine_patch or not nine_patch.texture:
		return 16.0
	return maxf(float(nine_patch.texture.get_height() - nine_patch.patch_margin_top - nine_patch.patch_margin_bottom), 0.0)


func _get_end_caps_size_x(expand: float = 0.0) -> float:
	if not nine_patch or not nine_patch.texture:
		return 16.0
	var full_width: float = float(nine_patch.texture.get_width())
	var margins: float = float(nine_patch.patch_margin_left + nine_patch.patch_margin_right)
	return (full_width if margins == 0.0 else margins) + expand


func _get_end_caps_size_y(expand: float = 0.0) -> float:
	if not nine_patch or not nine_patch.texture:
		return 16.0
	var full_height: float = float(nine_patch.texture.get_height())
	var margins: float = float(nine_patch.patch_margin_top + nine_patch.patch_margin_bottom)
	return (full_height if margins == 0.0 else margins) + expand


static func from_game_object(game_object: GameObject = null) -> LevelObjectTelescoping:
	if not game_object:
		return null
	
	var instance: LevelObjectTelescoping = preload("uid://dfaru2spj6lmk").instantiate()
	var atlas: AtlasTexture = game_object.telescoping_atlas
	
	if atlas and atlas.atlas:
		var full_size: Vector2 = atlas.atlas.get_size()
		var region: Rect2 = atlas.region
		var margin_left: int = int(region.position.x)
		var margin_top: int = int(region.position.y)
		var margin_right: int = int(full_size.x - (region.position.x + region.size.x))
		var margin_bottom: int = int(full_size.y - (region.position.y + region.size.y))
		
		instance.nine_patch.texture = atlas.atlas
		instance.nine_patch.patch_margin_left = margin_left
		instance.nine_patch.patch_margin_top = margin_top
		instance.nine_patch.patch_margin_right = margin_right
		instance.nine_patch.patch_margin_bottom = margin_bottom
		
		var min_x: float = float(margin_left + margin_right) if (margin_left + margin_right) > 0 else full_size.x
		var min_y: float = float(margin_top + margin_bottom) if (margin_top + margin_bottom) > 0 else full_size.y
		instance.nine_patch.size = Vector2(min_x, min_y)
		instance.nine_patch.position = -instance.nine_patch.size / 2.0
		instance.nine_patch.custom_minimum_size = instance.nine_patch.size
		instance._initial_nine_patch_size = instance.nine_patch.size
		instance._collision_expand = game_object.collision_expand
		instance._collision_offset = game_object.collision_offset
		instance._collision_collapsed = game_object.collision_collapsed
		instance._collision_anchor = game_object.collision_anchor
	
	for col: CollisionShape2D in instance.collision_shapes:
		col.one_way_collision = game_object.collision_one_way
		col.one_way_collision_margin = game_object.collision_one_way_margin
	
	return instance
