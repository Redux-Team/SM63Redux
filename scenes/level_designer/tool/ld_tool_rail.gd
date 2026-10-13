class_name LDToolRail
extends LDComponent

const ANIM_DURATION: float = 0.22

@export var bar: BoxContainer
@export var clip: Control
@export var placement_button: BaseButton
@export var rotate_button: BaseButton
@export var scale_button: BaseButton
@export var hidden_buttons: Array[Control]
@export var placement_icons: Dictionary[ObjectShape.Kind, Texture2D]
@export var placement_tooltips: Dictionary[ObjectShape.Kind, String]

var _shown: Dictionary[Control, bool] = {}
var _tween: Tween
var _dirty: bool = false


func _setup() -> void:
	for button: Control in hidden_buttons:
		button.visible = false
	editor.tool_handler.armed_changed.connect(_on_armed_changed)
	editor.object_handler.selection.changed.connect(_on_selection_changed)
	clip.custom_minimum_size.y = _bar_length()
	_on_armed_changed(null)
	_on_selection_changed()


func _on_armed_changed(entry: ObjectRegistry.Entry) -> void:
	var kind: ObjectShape.Kind = entry.get_shape_kind() if entry else ObjectShape.Kind.NONE
	if placement_icons.has(kind):
		placement_button.icon = placement_icons.get(kind)
	Tooltip.set_text(placement_button, placement_tooltips.get(kind, Tooltip.get_text(placement_button)), Tooltip.Placement.RIGHT)


func _on_selection_changed() -> void:
	var objects: Array[GameObject] = editor.object_handler.selection.get_objects()
	_set_shown(rotate_button, objects.any(func(object: GameObject) -> bool: return object.has_flag(GameObject.Flag.ROTATABLE)))
	_set_shown(scale_button, objects.any(func(object: GameObject) -> bool: return object.has_flag(GameObject.Flag.SCALABLE)))


func _set_shown(button: Control, shown: bool) -> void:
	if _shown.get_or_add(button, button.visible) == shown:
		return
	
	_shown.set(button, shown)
	if not _dirty:
		_dirty = true
		_animate.call_deferred()


func _animate() -> void:
	_dirty = false
	if _tween and _tween.is_valid():
		_tween.kill()
	
	for button: Control in _shown:
		if _shown.get(button):
			button.visible = true
	
	var duration: float = ANIM_DURATION if Settings.ui.animations.current_value else 0.0
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(clip, ^"custom_minimum_size:y", _bar_length(), duration)
	_tween.finished.connect(_settle)


func _settle() -> void:
	for button: Control in _shown:
		button.visible = _shown.get(button)
	
	var tool: LDTool = editor.tool_handler.active_tool
	if tool.button and not _shown.get(tool.button, true):
		editor.tool_handler.set_tool(editor.tool_handler.default_tool)


func _bar_length() -> float:
	var total: float = 0.0
	var count: int = 0
	for child: Node in bar.get_children():
		var item: Control = child as Control
		if item and _shown.get(item, item.visible):
			total += item.get_combined_minimum_size().y
			count += 1
	
	return total + bar.get_theme_constant(&"separation") * maxi(count - 1, 0)
