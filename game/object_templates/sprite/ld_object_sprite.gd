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


static func from_data(data: GameObjectData) -> LDObject:
	var sprite_data: SpriteData = data as SpriteData
	if not sprite_data:
		return null

	var instance: LDObjectSprite = load("uid://qn5edo21q3sg").instantiate()
	instance.sprite_ref.diffuse_texture = sprite_data.texture

	var editor_shape: CollisionShape2D = instance.editor_placement_rect
	editor_shape.shape = sprite_data.editor_shape_override if sprite_data.editor_shape_override else Packer.get_texture_as_shape(sprite_data.texture)
	editor_shape.position = sprite_data.editor_shape_offset

	return instance


func _on_preview() -> void:
	reset_shader_modulate()


func _on_place() -> void:
	reset_shader_modulate()


## The sprite carries its own instance of the object shader, so it needs the parameter too.
func set_shader_parameter(parameter: StringName, value: Variant) -> void:
	super(parameter, value)
	if sprite_ref and sprite_ref.material is ShaderMaterial:
		(sprite_ref.material as ShaderMaterial).set_shader_parameter(parameter, value)


func _setup_sprite_material(s: SmartSprite2D) -> void:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load("uid://dxlbj210tsi10")
	mat.resource_local_to_scene = true
	s.material = mat
