@warning_ignore_start("unused_private_class_variable")
@tool
class_name LDObject
extends Node2D


enum PlacementRules {
	PLACE,
	EXPAND_CENTER_X,
	EXPAND_EDGES_X,
}


@export var placement_rules: PlacementRules = PlacementRules.PLACE
@export var is_preview: bool = true:
	set(v):
		is_preview = v
		if is_preview:
			_on_preview()
		else:
			_on_place()

@export_group("Editor Props")
@export var sprite_ref: Sprite2D
@export var editor_shape_area: Area2D
@export var editor_placement_rect: CollisionShape2D
@export var origin_marker: Marker2D

@export_tool_button("Create Editor Props") var _create_editor_props: Callable:
	get: return func() -> void:
		if not sprite_ref:
			sprite_ref = Sprite2D.new()
			sprite_ref.name = "Sprite"
			add_child(sprite_ref)
			sprite_ref.owner = self
		
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
	modulate = Color(1.0, 1.0, 1.0, 0.6)


func _on_place() -> void:
	modulate = Color.WHITE


## Override to define custom placement behavior [b]before[/b] the object is placed.
## Return true when finished.
func _placement_rules() -> bool:
	return true


## Behavior for when the placement is confirmed.
func place() -> void:
	is_preview = false


## Override to define hover behavior.
func _hover_rules() -> void:
	pass


func get_stamp_size() -> Vector2:
	if not editor_placement_rect:
		return Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE)
	return (editor_placement_rect.shape as RectangleShape2D).get_rect().size
