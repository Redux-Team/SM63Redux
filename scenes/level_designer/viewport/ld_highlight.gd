class_name LDHighlight
extends LDComponent

enum HighlightState {
	NONE,
	HOVERED,
	SELECTED,
}

const SHADER: Shader = preload("res://shader/ld_selection.gdshader")
const ORIGINAL: StringName = &"ld_original_material"

var hovered: GameObject
var _states: Dictionary = {}
var _materials: Dictionary[HighlightState, ShaderMaterial] = {}
var _hover_dirty: bool = true


func _setup() -> void:
	for state: HighlightState in [HighlightState.HOVERED, HighlightState.SELECTED]:
		_materials.set(state, _make_material(state, null))
	editor.object_handler.selection.changed.connect(_sync)
	editor.object_handler.objects_changed.connect(_on_objects_changed)
	editor.tool_handler.tool_changed.connect(_mark_hover.unbind(1))
	editor.viewport_handler.input_surface.gui_input.connect(_on_gui_input)
	editor.viewport_handler.input_surface.mouse_exited.connect(_mark_hover)


func _process(_delta: float) -> void:
	if not _hover_dirty:
		return
	
	_hover_dirty = false
	var next: GameObject = null
	if _hover_allowed():
		next = editor.viewport_handler.pick(editor.viewport_handler.get_world_mouse())
	if next != hovered:
		hovered = next
		_sync()


static func has_texture_visuals(object: GameObject) -> bool:
	return not object.shape is PolygonShape and not _collect(object).is_empty()


func get_state(object: GameObject) -> HighlightState:
	return _states.get(object, HighlightState.NONE)


func _hover_allowed() -> bool:
	var input_surface: Control = editor.viewport_handler.input_surface
	if not input_surface.get_global_rect().has_point(input_surface.get_global_mouse_position()):
		return false
	
	var tool: LDTool = editor.tool_handler.active_tool
	return tool is LDSelectTool or tool is LDMoveTool or tool is LDWidgetTool


func _mark_hover() -> void:
	_hover_dirty = true


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_hover_dirty = true


func _on_objects_changed() -> void:
	_hover_dirty = true
	for key: Variant in _states.keys():
		if is_instance_valid(key):
			_apply(key, HighlightState.NONE)
	_states.clear()
	_sync()


func _sync() -> void:
	var wanted: Dictionary[GameObject, HighlightState] = {}
	if is_instance_valid(hovered):
		wanted.set(hovered, HighlightState.HOVERED)
	for object: GameObject in editor.object_handler.selection.get_objects():
		wanted.set(object, HighlightState.SELECTED)
	
	for key: Variant in _states.keys():
		if not is_instance_valid(key):
			_states.erase(key)
		elif not wanted.has(key):
			_apply(key, HighlightState.NONE)
			_states.erase(key)
	
	for object: GameObject in wanted:
		var state: HighlightState = wanted.get(object)
		if _states.get(object, HighlightState.NONE) != state:
			_apply(object, state)
			_states.set(object, state)


func _apply(object: GameObject, state: HighlightState) -> void:
	if object.shape is PolygonShape:
		return
	
	for item: CanvasItem in _collect(object):
		if state == HighlightState.NONE:
			if item.has_meta(ORIGINAL):
				item.material = item.get_meta(ORIGINAL)
				item.remove_meta(ORIGINAL)
			continue
		
		if not item.has_meta(ORIGINAL):
			item.set_meta(ORIGINAL, item.material)
		var original: ShaderMaterial = item.get_meta(ORIGINAL) as ShaderMaterial
		if original and original.get_shader_parameter(&"palette_texture") != null:
			item.material = _make_material(state, original)
		else:
			item.material = _materials.get(state)


func _make_material(state: HighlightState, palette_source: ShaderMaterial) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter(&"state", state)
	if palette_source:
		material.set_shader_parameter(&"palette_texture", palette_source.get_shader_parameter(&"palette_texture"))
	
	return material


static func _collect(root: Node) -> Array[CanvasItem]:
	var items: Array[CanvasItem] = []
	for child: Node in root.get_children():
		if child is CanvasItem and not (child as CanvasItem).visible:
			continue
		
		if _is_textured(child):
			items.append(child)
		items.append_array(_collect(child))
	
	return items


static func _is_textured(node: Node) -> bool:
	if node is Sprite2D:
		return (node as Sprite2D).texture != null
	if node is NinePatchRect:
		return (node as NinePatchRect).texture != null
	if node is TextureRect:
		return (node as TextureRect).texture != null
	if node is Line2D:
		return (node as Line2D).texture != null
	
	return node is AnimatedSprite2D
