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


@warning_ignore("unused_private_class_variable")
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
	if not nine_patch:
		return 15
	return nine_patch.patch_margin_left + nine_patch.patch_margin_right


func get_end_collision_height() -> int:
	if not nine_patch:
		return 15
	return nine_patch.patch_margin_top + nine_patch.patch_margin_bottom


func get_total_width(units: int) -> float:
	return get_middle_segment_width() * units + get_end_collision_width()


func get_total_height(units: int) -> float:
	return get_middle_segment_height() * units + get_end_collision_height()


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
	var half: float = total / 2.0
	
	if nine_patch:
		nine_patch.size.x = total
		nine_patch.position.x = -half
	
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
	var half: float = roundi(total / 2.0)
	
	if nine_patch:
		nine_patch.size.y = total
		nine_patch.position.y = -half
	
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
		(nine_patch.material as ShaderMaterial).set_shader_parameter(&"custom_modulate", color)


func _setup_sprite_material(_s: Sprite2D) -> void:
	pass


func _setup_nine_patch_material(np: NinePatchRect) -> void:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load("uid://dxlbj210tsi10")
	mat.resource_local_to_scene = true
	np.material = mat
