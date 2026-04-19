@warning_ignore_start("unused_private_class_variable")
@tool
class_name LDObjectSprite
extends LDObject


@export_group("Debug")
@export var sprite_ref: Sprite2D
@export_tool_button("Create Sprite Props") var _create_sprite_props: Callable:
	get: return func() -> void:
		if not sprite_ref:
			sprite_ref = SmartSprite2D.new()
			sprite_ref.name = "Sprite"
			add_child(sprite_ref)
			sprite_ref.owner = self
			_setup_sprite_material(sprite_ref)
		
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
			
			if not editor_placement_rect:
				editor_placement_rect = editor_shape
		
		if not origin_marker:
			origin_marker = Marker2D.new()
			origin_marker.name = "Origin"
			add_child(origin_marker)
			origin_marker.owner = self


func _on_preview() -> void:
	set_shader_modulate(Color(1.0, 1.0, 1.0, 0.6))


func _on_place() -> void:
	set_shader_modulate(Color.WHITE)


func set_selection_state(state: LDObject.SelectionState) -> void:
	_set_shader_param(&"state", state)


func set_shader_modulate(color: Color) -> void:
	_set_shader_param(&"custom_modulate", color)


func reset_shader_modulate() -> void:
	set_shader_modulate(Color.WHITE if not is_preview else Color(1.0, 1.0, 1.0, 0.6))


func _set_shader_param(param: StringName, value: Variant) -> void:
	for shader_obj: CanvasItem in shader_objects:
		if shader_obj and shader_obj.material:
			shader_obj.material.set_shader_parameter(param, value)
	
	if sprite_ref and sprite_ref.material:
		sprite_ref.material.set_shader_parameter(param, value)



func _setup_sprite_material(s: SmartSprite2D) -> void:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load("uid://dxlbj210tsi10")
	mat.resource_local_to_scene = true
	s.material = mat
