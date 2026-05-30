@warning_ignore_start("unused_private_class_variable")
@tool
class_name LDObjectTelescoping
extends LDObjectSprite

## The minimum number of middle segments allowed.
@export var min_units: int = 0
## The maximum number of middle segments allowed (-1 for unlimited).
@export var max_units: int = 32

@export_group("Telescoping Refs")
## NinePatchRect that renders the full telescoping visual.
@export var nine_patch: NinePatchRect
## Optional secondary Area2D that sits on top of the platform surface.
@export var safety_net: Area2D

var _selection_state: SelectionState = SelectionState.HIDDEN
var _initial_nine_patch_size: Vector2


@export_tool_button("Create Telescoping Props") var _create_telescoping_props: Callable:
	get: return func() -> void:
		if not nine_patch:
			var np: NinePatchRect = NinePatchRect.new()
			np.name = "NinePatch"
			np.draw_center = true
			np.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
			np.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
			add_child(np)
			np.owner = self
			nine_patch = np
			_setup_nine_patch_material(np)
		
		if not editor_shape_area:
			editor_shape_area = Area2D.new()
			editor_shape_area.name = "EditorShapeArea"
			add_child(editor_shape_area)
			editor_shape_area.owner = self
			
			var editor_shape: CollisionShape2D = CollisionShape2D.new()
			editor_shape.name = "EditorShape"
			editor_shape_area.add_child(editor_shape)
			editor_shape.owner = self
			editor_shape.shape = RectangleShape2D.new()
			editor_shape.shape.resource_local_to_scene = true
			
			if not editor_placement_rect:
				editor_placement_rect = editor_shape
		
		if not origin_marker:
			origin_marker = Marker2D.new()
			origin_marker.name = "Origin"
			add_child(origin_marker)
			origin_marker.owner = self


static func from_game_object(game_object: GameObject = null) -> LDObject:
	if not game_object:
		return null
	
	var instance: LDObjectTelescoping = preload("uid://c618q1hl6by83").instantiate()
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
		
		var editor_shape: CollisionShape2D = instance.editor_placement_rect
		if editor_shape:
			if game_object.editor_shape_shape_override:
				editor_shape.shape = game_object.editor_shape_shape_override
			else:
				var rect: RectangleShape2D = RectangleShape2D.new()
				rect.size = Vector2(min_x, min_y) + game_object.collision_expand
				rect.resource_local_to_scene = true
				editor_shape.shape = rect
			editor_shape.position = game_object.collision_offset
	
	return instance


func set_selection_state(state: SelectionState) -> void:
	_selection_state = state
	_sync_shader_state()
	queue_redraw()


func _sync_shader_state() -> void:
	if not nine_patch or not nine_patch.material is ShaderMaterial:
		return
	(nine_patch.material as ShaderMaterial).set_shader_parameter(&"state", int(_selection_state))


func _draw() -> void:
	pass


func is_telescoping_x() -> bool:
	return has_property(&"t_size_x")


func is_telescoping_y() -> bool:
	return has_property(&"t_size_y")


func clamp_units(units: int) -> int:
	var result: int = maxi(units, min_units)
	if max_units >= 0:
		result = mini(result, max_units)
	return result


func get_middle_segment_width() -> int:
	if not nine_patch or not nine_patch.texture:
		return 16
	return nine_patch.texture.get_width() - nine_patch.patch_margin_left - nine_patch.patch_margin_right


func get_middle_segment_height() -> int:
	if not nine_patch or not nine_patch.texture:
		return 16
	return nine_patch.texture.get_height() - nine_patch.patch_margin_top - nine_patch.patch_margin_bottom


func get_end_segment_width() -> int:
	if not nine_patch:
		return 8
	return nine_patch.patch_margin_left


func get_end_segment_height() -> int:
	if not nine_patch:
		return 8
	return nine_patch.patch_margin_top


func get_end_collision_width() -> int:
	if not nine_patch or not nine_patch.texture:
		return 15
	var margins: int = nine_patch.patch_margin_left + nine_patch.patch_margin_right
	return nine_patch.texture.get_width() if margins == 0 else margins


func get_end_collision_height() -> int:
	if not nine_patch or not nine_patch.texture:
		return 15
	var margins: int = nine_patch.patch_margin_top + nine_patch.patch_margin_bottom
	return nine_patch.texture.get_height() if margins == 0 else margins


func get_total_width(units: int) -> float:
	return float(get_middle_segment_width() * units + get_end_collision_width())


func get_total_height(units: int) -> float:
	return float(get_middle_segment_height() * units + get_end_collision_height())


func _on_preview() -> void:
	_set_all_modulate(Color(1.0, 1.0, 1.0, 0.6))


func _on_place() -> void:
	_set_all_modulate(Color.WHITE)


func _on_property_changed(key: StringName, value: Variant) -> void:
	match key:
		&"t_size_x":
			_apply_width(value)
		&"t_size_y":
			_apply_height(value)


func _apply_width(units: int) -> void:
	units = clamp_units(units)
	var total: float = get_total_width(units)
	
	if nine_patch:
		nine_patch.size.x = total
		nine_patch.position.x = -total / 2.0
	
	if editor_placement_rect and editor_placement_rect.shape is RectangleShape2D:
		(editor_placement_rect.shape as RectangleShape2D).size.x = total
	
	if safety_net:
		var safety_shape: CollisionShape2D = safety_net.get_child(0) as CollisionShape2D
		if safety_shape and safety_shape.shape is RectangleShape2D:
			(safety_shape.shape as RectangleShape2D).size.x = total
	
	_sync_shader_state()


func _apply_height(units: int) -> void:
	units = clamp_units(units)
	var total: float = get_total_height(units)
	
	if nine_patch:
		nine_patch.size.y = total
		nine_patch.position.y = -float(roundi(total / 2.0))
	
	if editor_placement_rect and editor_placement_rect.shape is RectangleShape2D:
		(editor_placement_rect.shape as RectangleShape2D).size.y = total
	
	if safety_net:
		var safety_shape: CollisionShape2D = safety_net.get_child(0) as CollisionShape2D
		if safety_shape and safety_shape.shape is RectangleShape2D:
			(safety_shape.shape as RectangleShape2D).size.y = total
	
	_sync_shader_state()


func _set_all_modulate(color: Color) -> void:
	if nine_patch:
		nine_patch.modulate = color
		(nine_patch.material as ShaderMaterial).set_shader_parameter(&"post_modulate", color)


func _setup_sprite_material(_s: Sprite2D) -> void:
	pass


func _setup_nine_patch_material(np: NinePatchRect) -> void:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load("uid://dxlbj210tsi10")
	mat.resource_local_to_scene = true
	np.material = mat
