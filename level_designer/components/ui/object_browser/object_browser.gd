class_name LDObjectBrowser
extends Control

signal category_changed(category_name: String)
signal hide_request

const OBJECT_GROUP_SCENE = preload("uid://d11ohrgxcihxx")

@export var groups_v_box: VBoxContainer
@export var category_buttons_container: HBoxContainer
@export var tooltip_label: Label

var _tab_button_group: ButtonGroup = ButtonGroup.new()
var _tooltip_anchor: Control = null


func _init() -> void:
	_tab_button_group.allow_unpress = true


func _ready() -> void:
	_tab_button_group.pressed.connect(_on_tab_button_group_pressed)
	_populate_category_buttons()
	populate_list()
	tooltip_label.hide()


func _process(_delta: float) -> void:
	if not tooltip_label.visible:
		return
	if _tooltip_anchor:
		var rect: Rect2 = _tooltip_anchor.get_global_rect()
		tooltip_label.global_position = Vector2(
			rect.position.x + (rect.size.x - tooltip_label.size.x) / 2.0,
			rect.position.y + rect.size.y + 4.0
		)
	else:
		var mouse: Vector2 = get_global_mouse_position()
		tooltip_label.global_position = mouse + Vector2(12.0, 12.0)


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


func _on_tab_button_group_pressed(button: BaseButton) -> void:
	_play_sfx(button != null)
	populate_list()


func populate_list() -> void:
	for n: Node in groups_v_box.get_children():
		n.queue_free()
	
	var pressed: BaseButton = _tab_button_group.get_pressed_button()
	var cat_name: String = pressed.name if pressed else ""
	
	var groups: Array[GameDB.GameObjectGroup] = []
	if cat_name.is_empty():
		for cat: GameDB.GameObjectCategory in GameDB.get_db().get_tree():
			groups.append_array(cat.get_groups())
	else:
		var cat: GameDB.GameObjectCategory = GameDB.get_db().get_category(cat_name)
		if cat:
			groups = cat.get_groups()
	
	for group: GameDB.GameObjectGroup in groups:
		var indexable: Array[GameObject] = group.get_objects().filter(
			func(o: GameObject) -> bool: return o.ld_indexable
		)
		if indexable.is_empty():
			continue
		var group_node: LDObjectBrowserGroup = OBJECT_GROUP_SCENE.instantiate()
		group_node.set_group_name(group.get_name())
		groups_v_box.add_child(group_node)
		group_node.entry_selected.connect(_on_entry_selected)
		group_node.entry_hovered.connect(_on_entry_hovered)
		group_node.entry_unhovered.connect(_on_entry_unhovered)
		group_node.entry_focused.connect(_on_entry_focused)
		group_node.entry_unfocused.connect(_on_entry_unhovered)
		for obj: GameObject in indexable:
			group_node.add_entry(obj)
	
	var display_name: String = pressed.text if pressed else "All"
	category_changed.emit(display_name.to_pascal_case())


func _on_entry_selected(obj: GameObject) -> void:
	LD.get_object_handler().select_object(obj)
	LD.get_tool_handler().select_tool("Brush")
	hide_request.emit()


func _on_entry_hovered(obj: GameObject) -> void:
	_tooltip_anchor = null
	tooltip_label.text = obj.get_object_name()
	tooltip_label.size = Vector2.ZERO
	tooltip_label.show()


func _on_entry_focused(obj: GameObject, entry: Control) -> void:
	_tooltip_anchor = entry
	tooltip_label.text = obj.get_object_name()
	tooltip_label.size = Vector2.ZERO
	tooltip_label.show()


func _on_entry_unhovered() -> void:
	_tooltip_anchor = null
	tooltip_label.hide()
	tooltip_label.size = Vector2.ZERO


func _play_sfx(toggled_on: bool) -> void:
	if toggled_on:
		SFX.play(SFX.LD_SELECT)
	else:
		SFX.play(SFX.LD_BACK)
