class_name LDObjectBrowser
extends Control


signal category_changed(category_name: String)
signal hide_request


const OBJECT_GROUP_SCENE: PackedScene = preload("uid://d11ohrgxcihxx")
const GROUP_ITEM_ENTRY: PackedScene = preload("uid://cmh307lx6bbro")
const TOOLTIP_MARGIN: float = 8.0


@export var groups_v_box: VBoxContainer
@export var category_buttons_container: HBoxContainer
@export var tooltip_label: RichTextLabel
@export var search_line_edit: LineEdit


var _tab_button_group: ButtonGroup = ButtonGroup.new()
var _tooltip_anchor: Control = null
var _showing_ld_groups: bool = false
var _groups_button: Button = null


func _init() -> void:
	_tab_button_group.allow_unpress = true


func _ready() -> void:
	_tab_button_group.pressed.connect(_on_tab_button_group_pressed)
	_populate_category_buttons()
	populate_list()
	tooltip_label.hide()
	
	var gh: LDGroupHandler = LD.get_group_handler()
	gh.group_added.connect(_on_groups_changed)
	gh.group_removed.connect(_on_groups_changed_by_id)
	gh.group_changed.connect(_on_groups_changed)


func _on_show() -> void:
	_refresh_groups_tab()


func _process(_delta: float) -> void:
	if not tooltip_label.visible:
		return
	
	var raw_pos: Vector2
	if _tooltip_anchor:
		var rect: Rect2 = _tooltip_anchor.get_global_rect()
		raw_pos = Vector2(
			rect.position.x + (rect.size.x - tooltip_label.size.x) / 2.0,
			rect.position.y + rect.size.y + 4.0
		)
	else:
		raw_pos = get_global_mouse_position() + Vector2(12.0, 12.0)
	
	tooltip_label.global_position = _clamp_to_window(raw_pos)


func _clamp_to_window(pos: Vector2) -> Vector2:
	var window_size: Vector2 = get_viewport().get_visible_rect().size
	var tip_size: Vector2 = tooltip_label.size
	return Vector2(
		clampf(pos.x, TOOLTIP_MARGIN, window_size.x - tip_size.x - TOOLTIP_MARGIN),
		clampf(pos.y, TOOLTIP_MARGIN, window_size.y - tip_size.y - TOOLTIP_MARGIN)
	)


func _populate_category_buttons() -> void:
	for cat_name: String in GameDB.get_db().get_category_names():
		var button: Button = Button.new()
		button.text = cat_name.to_pascal_case()
		button.name = cat_name
		button.toggle_mode = true
		button.button_group = _tab_button_group
		button.custom_minimum_size.x = 80
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		category_buttons_container.add_child(button)
	
	var groups_button: Button = Button.new()
	groups_button.text = "Groups"
	groups_button.name = "__ld_groups__"
	groups_button.toggle_mode = true
	groups_button.button_group = _tab_button_group
	groups_button.custom_minimum_size.x = 80
	groups_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	groups_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_buttons_container.add_child(groups_button)
	_groups_button = groups_button
	_update_groups_tab_visibility()


func _on_tab_button_group_pressed(button: BaseButton) -> void:
	_play_sfx(button != null)
	_showing_ld_groups = button != null and button.name == "__ld_groups__"
	if _showing_ld_groups:
		_populate_groups_list()
		category_changed.emit("Groups")
	else:
		populate_list()


func _on_search_line_edit_text_changed(new_text: String) -> void:
	if _showing_ld_groups:
		return
	populate_list(new_text)


func _refresh_groups_tab() -> void:
	if _showing_ld_groups:
		_populate_groups_list()


func _populate_groups_list() -> void:
	for n: Node in groups_v_box.get_children():
		n.queue_free()
	
	var placeable: Array[LDGroup] = LD.get_group_handler().get_all_groups()

	if placeable.is_empty():
		return
	
	var group_node: LDObjectBrowserGroup = OBJECT_GROUP_SCENE.instantiate()
	group_node.set_group_name("Groups")
	groups_v_box.add_child(group_node)
	
	for group: LDGroup in placeable:
		var entry: LDGroupItemEntry = GROUP_ITEM_ENTRY.instantiate()
		entry.setup(group)
		entry.entry_selected.connect(_on_group_entry_selected, CONNECT_REFERENCE_COUNTED)
		entry.entry_mouse_entered.connect(_on_group_entry_hovered, CONNECT_REFERENCE_COUNTED)
		entry.entry_mouse_exited.connect(_on_group_entry_unhovered, CONNECT_REFERENCE_COUNTED)
		entry.entry_focus_entered.connect(_on_group_entry_focused, CONNECT_REFERENCE_COUNTED)
		entry.entry_focus_exited.connect(_on_group_entry_unhovered, CONNECT_REFERENCE_COUNTED)
		group_node.group_list.add_child(entry)


func populate_list(search: String = "") -> void:
	for n: Node in groups_v_box.get_children():
		n.queue_free()
	
	var query: String = search.to_lower().strip_edges()
	var pressed: BaseButton = _tab_button_group.get_pressed_button()
	
	var all_groups: Array[GameDB.GameObjectGroup] = []
	if query.is_empty():
		var cat_name: String = pressed.name if pressed else &""
		if cat_name.is_empty() or cat_name == "__ld_groups__":
			for cat: GameDB.GameObjectCategory in GameDB.get_db().get_tree():
				all_groups.append_array(cat.get_groups())
		else:
			var cat: GameDB.GameObjectCategory = GameDB.get_db().get_category(cat_name)
			if cat:
				all_groups = cat.get_groups()
	else:
		for cat: GameDB.GameObjectCategory in GameDB.get_db().get_tree():
			all_groups.append_array(cat.get_groups())
	
	for group: GameDB.GameObjectGroup in all_groups:
		var indexable: Array[GameObject] = group.get_objects().filter(
			func(o: GameObject) -> bool: return o.ld_indexable
		)
		if indexable.is_empty():
			continue
		
		var scored: Array[Dictionary] = []
		for obj: GameObject in indexable:
			if query.is_empty():
				scored.append({"obj": obj, "score": 0})
				continue
			var score: int = _fuzzy_score(query, obj.get_object_name().to_lower())
			if score <= 0:
				continue
			scored.append({"obj": obj, "score": score})
		
		if scored.is_empty():
			continue
		
		if not query.is_empty():
			scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return a.get("score", 0) > b.get("score", 0)
			)
		
		var group_node: LDObjectBrowserGroup = OBJECT_GROUP_SCENE.instantiate()
		group_node.set_group_name(group.get_name())
		groups_v_box.add_child(group_node)
		group_node.entry_selected.connect(_on_entry_selected)
		group_node.entry_hovered.connect(_on_entry_hovered)
		group_node.entry_unhovered.connect(_on_entry_unhovered)
		group_node.entry_focused.connect(_on_entry_focused)
		group_node.entry_unfocused.connect(_on_entry_unhovered)
		for item: Dictionary in scored:
			group_node.add_entry(item.get("obj") as GameObject)
	
	var display_name: String = pressed.text if pressed else "All"
	category_changed.emit(display_name.to_pascal_case())


func _fuzzy_score(query: String, text: String) -> int:
	if text == query:
		return 1000
	if text.begins_with(query):
		return 800
	if text.contains(query):
		return 600
	var qi: int = 0
	var last_match: int = -1
	var proximity_bonus: int = 0
	for ti: int in text.length():
		if qi >= query.length():
			break
		if text[ti] == query[qi]:
			if last_match >= 0:
				proximity_bonus += maxi(0, 10 - (ti - last_match))
			last_match = ti
			qi += 1
	if qi < query.length():
		return 0
	return 200 + proximity_bonus


func _on_group_entry_selected(entry: LDGroupItemEntry) -> void:
	var group: LDGroup = entry.group_ref
	LD.get_group_handler().arm_group(group)
	LD.get_tool_handler().select_tool("place")
	hide_request.emit()


func _on_group_entry_hovered(entry: LDGroupItemEntry) -> void:
	_tooltip_anchor = null
	tooltip_label.text = entry.group_ref.id
	tooltip_label.size = Vector2.ZERO
	tooltip_label.show()


func _on_group_entry_focused(entry: LDGroupItemEntry) -> void:
	_tooltip_anchor = entry
	tooltip_label.text = entry.group_ref.id
	tooltip_label.size = Vector2.ZERO
	tooltip_label.show()


func _on_group_entry_unhovered(_entry: LDGroupItemEntry) -> void:
	_tooltip_anchor = null
	tooltip_label.hide()
	tooltip_label.size = Vector2.ZERO


func _on_groups_changed(_group: LDGroup) -> void:
	_update_groups_tab_visibility()
	if _showing_ld_groups:
		_populate_groups_list()


func _on_groups_changed_by_id(_group_id: String) -> void:
	_update_groups_tab_visibility()
	if _showing_ld_groups:
		_populate_groups_list()


func _has_placeable_groups() -> bool:
	return not LD.get_group_handler().get_all_groups().is_empty()


func _update_groups_tab_visibility() -> void:
	if not is_instance_valid(_groups_button):
		return
	var has_groups: bool = _has_placeable_groups()
	_groups_button.visible = has_groups
	if not has_groups and _showing_ld_groups:
		_showing_ld_groups = false
		_groups_button.set_pressed_no_signal(false)
		populate_list()


func _on_entry_selected(obj: GameObject) -> void:
	LD.get_object_handler().select_object(obj)
	LD.get_tool_handler().select_tool("Brush")
	hide_request.emit()


func _on_entry_hovered(obj: GameObject) -> void:
	_tooltip_anchor = null
	_show_tooltip(obj)


func _on_entry_focused(obj: GameObject, entry: Control) -> void:
	_tooltip_anchor = entry
	_show_tooltip(obj)


func _on_entry_unhovered() -> void:
	_tooltip_anchor = null
	tooltip_label.hide()
	tooltip_label.size = Vector2.ZERO


func _show_tooltip(obj: GameObject) -> void:
	var query: String = search_line_edit.text.to_lower().strip_edges()
	tooltip_label.text = _highlight_match(query, obj.get_object_name())
	tooltip_label.size = Vector2.ZERO
	tooltip_label.show()


func _highlight_match(query: String, text: String) -> String:
	if query.is_empty():
		return text
	var lower_text: String = text.to_lower()
	var lower_query: String = query.to_lower()
	var indices: Array[int] = []
	var substring_start: int = lower_text.find(lower_query)
	if substring_start >= 0:
		for i: int in lower_query.length():
			indices.append(substring_start + i)
	else:
		var qi: int = 0
		for ti: int in lower_text.length():
			if qi >= lower_query.length():
				break
			if lower_text[ti] == lower_query[qi]:
				indices.append(ti)
				qi += 1
		if qi < lower_query.length():
			return text
	var result: String = ""
	for i: int in text.length():
		if i in indices:
			result += "[color=yellow]" + text[i] + "[/color]"
		else:
			result += text[i]
	return result


func _play_sfx(toggled_on: bool) -> void:
	if toggled_on:
		SFX.play(SFX.LD_SELECT)
	else:
		SFX.play(SFX.LD_BACK)
