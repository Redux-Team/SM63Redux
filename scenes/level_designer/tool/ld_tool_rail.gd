class_name LDToolRail
extends LDComponent

const ANIM_DURATION: float = 0.22
const FLYOUT_DURATION: float = 0.14
const FLYOUT_CLOSE_DELAY: float = 0.25
const FLYOUT_GAP: float = 6.0

@export var bar: BoxContainer
@export var clip: Control
@export var placement_button: BaseButton
@export var rotate_button: BaseButton
@export var scale_button: BaseButton
@export var hidden_buttons: Array[Control]
@export var topline_button: Control
@export var flyout: Control
@export var subtools: Container
@export var placement_icons: Dictionary[ObjectShape.Kind, Texture2D]
@export var placement_tooltips: Dictionary[ObjectShape.Kind, String]

var _shown: Dictionary[Control, bool] = {}
var _flyout_tween: Tween
var _flyout_open: bool = false
var _flyout_idle: float = 0.0
var _available: bool = false
var _placement_tip: String = ""
var _tween: Tween
var _dirty: bool = false


func _setup() -> void:
	for button: Control in hidden_buttons:
		button.visible = false
	editor.tool_handler.armed_changed.connect(_on_armed_changed)
	editor.object_handler.selection.changed.connect(_on_selection_changed)
	clip.custom_minimum_size.y = _bar_length()
	clip.clip_contents = false
	flyout.visible = false
	placement_button.mouse_entered.connect(_on_placement_hovered)
	editor.tool_handler.tool_changed.connect(_on_tool_changed.unbind(1))
	_on_armed_changed(null)
	_on_selection_changed()


func _on_armed_changed(entry: ObjectRegistry.Entry) -> void:
	var kind: ObjectShape.Kind = entry.get_shape_kind() if entry else ObjectShape.Kind.NONE
	if placement_icons.has(kind):
		placement_button.icon = placement_icons.get(kind)
	_placement_tip = placement_tooltips.get(kind, _placement_tip if not _placement_tip.is_empty() else Tooltip.get_text(placement_button))
	_refresh_flyout()
	_on_tool_changed()


func _on_selection_changed() -> void:
	var objects: Array[GameObject] = editor.object_handler.selection.get_objects()
	_set_shown(rotate_button, objects.any(func(object: GameObject) -> bool: return not LDRotateTool.get_ring_keys(object).is_empty()))
	_set_shown(scale_button, objects.any(func(object: GameObject) -> bool: return object.has_flag(GameObject.Flag.SCALABLE)))
	_set_shown(topline_button, LDToplineTool.is_available(objects))
	_refresh_flyout()


func _set_shown(button: Control, shown: bool) -> void:
	if _shown.get_or_add(button, button.visible) == shown:
		return
	
	_shown.set(button, shown)
	if not _dirty:
		_dirty = true
		_animate.call_deferred()


func _process(delta: float) -> void:
	if not _flyout_open:
		return
	
	_place_flyout()
	var mouse: Vector2 = flyout.get_global_mouse_position()
	var hovered: bool = placement_button.get_global_rect().grow(FLYOUT_GAP).has_point(mouse) or flyout.get_global_rect().grow(FLYOUT_GAP).has_point(mouse)
	_flyout_idle = 0.0 if hovered else _flyout_idle + delta
	if _flyout_idle >= FLYOUT_CLOSE_DELAY or not placement_button.is_visible_in_tree():
		_close_flyout()


func _has_subtools() -> bool:
	return _available


func _refresh_flyout() -> void:
	var before: bool = false
	var after: bool = false
	var past_separator: bool = false
	var separator: Control = null
	for child: Node in subtools.get_children():
		if child is Separator:
			separator = child
			past_separator = true
			continue
		
		var shown: bool = _applies(_subtool_for(child as Control))
		(child as Control).visible = shown
		if shown and past_separator:
			after = true
		elif shown:
			before = true
	
	if separator:
		separator.visible = before and after
	_available = before or after
	Tooltip.set_text(placement_button, "" if _available else _placement_tip, Tooltip.Placement.RIGHT)
	if not _available:
		_close_flyout()
	flyout.reset_size()


func _subtool_for(button: Control) -> LDTool:
	for tool: LDTool in editor.tool_handler.get_tools():
		if tool.button == button:
			return tool
	
	return null


func _applies(tool: LDTool) -> bool:
	if tool == null:
		return false
	if tool is LDPolygonEditTool:
		return LDPolygonEditTool.get_target(editor.object_handler.selection.get_objects()) != null
	if tool is LDPolygonBooleanTool:
		return not (tool as LDPolygonBooleanTool).get_targets().is_empty()
	
	var kind: ObjectShape.Kind = editor.tool_handler.armed.get_shape_kind() if editor.tool_handler.armed else ObjectShape.Kind.NONE
	return tool.shape_kinds.has(kind)


func _on_placement_hovered() -> void:
	if _has_subtools() and not _flyout_open:
		_open_flyout()


func _on_tool_changed() -> void:
	var tool: LDTool = editor.tool_handler.active_tool
	if tool == null or tool.group_button != placement_button:
		tool = editor.tool_handler.get_last_subtool(placement_button) if _has_subtools() else null
	if tool and tool.group_button == placement_button and tool.button:
		placement_button.icon = (tool.button as Button).icon


func _open_flyout() -> void:
	_flyout_open = true
	_flyout_idle = 0.0
	flyout.visible = true
	flyout.reset_size()
	_place_flyout()
	set_process(true)
	_animate_flyout(Vector2.ONE, 1.0)


func _close_flyout() -> void:
	if not _flyout_open:
		return
	
	_flyout_open = false
	_animate_flyout(Vector2(0.6, 1.0), 0.0).finished.connect(func() -> void:
		if not _flyout_open:
			flyout.visible = false)


func _animate_flyout(target_scale: Vector2, target_alpha: float) -> Tween:
	if _flyout_tween and _flyout_tween.is_valid():
		_flyout_tween.kill()
	
	if target_alpha > 0.0 and flyout.modulate.a <= 0.01:
		flyout.scale = Vector2(0.6, 1.0)
	var duration: float = FLYOUT_DURATION if Settings.ui.animations.current_value else 0.0
	_flyout_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_flyout_tween.tween_property(flyout, ^"scale", target_scale, duration)
	_flyout_tween.tween_property(flyout, ^"modulate:a", target_alpha, duration)
	return _flyout_tween


func _place_flyout() -> void:
	var button_rect: Rect2 = placement_button.get_global_rect()
	var rail_right: float = bar.get_global_rect().end.x
	flyout.pivot_offset = Vector2(0.0, flyout.size.y * 0.5)
	flyout.global_position = Vector2(rail_right + FLYOUT_GAP * 2.0, button_rect.get_center().y - flyout.get_global_rect().size.y * 0.5)


func _animate() -> void:
	_dirty = false
	if _tween and _tween.is_valid():
		_tween.kill()
	
	for button: Control in _shown:
		if _shown.get(button):
			button.visible = true
	
	clip.clip_contents = true
	var duration: float = ANIM_DURATION if Settings.ui.animations.current_value else 0.0
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(clip, ^"custom_minimum_size:y", _bar_length(), duration)
	_tween.finished.connect(_settle)


func _settle() -> void:
	clip.clip_contents = false
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
