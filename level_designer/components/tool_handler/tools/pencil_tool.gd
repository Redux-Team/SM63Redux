extends LDTool

# TODO:
# 1. Probably modularize the "preview dragging" part of this
# 2. Make the dragged object actually use either a scene or full texture.
# 3. Figure out if this system so far can work for poly terrain

var preview_object: Sprite2D
var editor_root: Node2D

func get_tool_name() -> String:
	return "Pencil"


func _on_ready() -> void:
	get_tool_handler().add_tool(self)
	get_tool_handler().select_tool(self)
	
	preview_object = Sprite2D.new()
	preview_object.modulate = Color("#ffffff99")
	LD.get_object_handler().selected_object_changed.connect(_on_object_changed)
	if LD.get_object_handler().get_selected_object():
		_on_object_changed(LD.get_object_handler().get_selected_object())
	
	editor_root = LD.get_editor_viewport().get_root()
	LD.get_editor_viewport().viewport_moved.connect(_on_viewport_moved)
	
	editor_root.add_child(preview_object)


func _on_viewport_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		preview_object.position = editor_root.get_local_mouse_position().snapped(Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE))


func _on_viewport_moved(_pos: Vector2, _zoom: Vector2) -> void:
	_on_viewport_input(InputEventMouseMotion.new())


func _on_object_changed(obj: GameObject) -> void:
	preview_object.texture = obj.ld_preview_texture
