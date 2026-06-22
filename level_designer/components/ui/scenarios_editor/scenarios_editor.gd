class_name LDScenarioEditor
extends MarginContainer

## Editor for the level's scenarios. Left = scenario list (COMMON pinned first, plus
## numbered scenarios). Right = per-scenario toggles for every layer, tag and stamp.
## COMMON rows are Enabled/Disabled (the baseline); numbered scenarios are
## Inherit/Enabled/Disabled overrides on top of COMMON. Mirrors stamps_editor.gd.


const ROW_CLASS: StringName = &"ListRow"
const INDEX_META: StringName = &"scenario_index"


@export var row_container: VBoxContainer
@export var add_button: Button
@export var remove_button: Button
@export var move_up_button: Button
@export var move_down_button: Button

@export var empty_center: Control
@export var detail_content: Control
@export var shine_row: HBoxContainer
@export var name_edit: LineEdit
@export var shine_check: CheckButton
@export var area_row: HBoxContainer
@export var area_option: OptionButton
@export var layers_header: Label
@export var layers_container: VBoxContainer
@export var tags_header: Label
@export var tags_container: VBoxContainer
@export var stamps_header: Label
@export var stamps_container: VBoxContainer


var _rows: Array[Button] = []
var _row_group: ButtonGroup = ButtonGroup.new()
var _selected_index: int = -1


func _ready() -> void:
	add_button.pressed.connect(_on_add_pressed)
	remove_button.pressed.connect(_on_remove_pressed)
	move_up_button.pressed.connect(_on_move_pressed.bind(-1))
	move_down_button.pressed.connect(_on_move_pressed.bind(1))
	
	name_edit.text_changed.connect(_on_name_changed)
	shine_check.toggled.connect(_on_shine_toggled)
	area_option.item_selected.connect(_on_area_option_selected)
	
	var sh: LDScenarioHandler = LD.get_scenario_handler()
	sh.scenario_added.connect(_on_scenarios_changed.unbind(1))
	sh.scenario_removed.connect(_on_scenarios_changed.unbind(1))
	
	_refresh_list()


func _on_name_changed(_text: String) -> void:
	if _selected_index > LDScenario.COMMON_INDEX:
		LD.get_scenario_handler().set_display_name(_selected_index, LDText.sanitize_edit(name_edit))


func _on_shine_toggled(pressed: bool) -> void:
	if _selected_index > LDScenario.COMMON_INDEX:
		LD.get_scenario_handler().set_show_in_shine_select(_selected_index, pressed)


func _on_area_option_selected(sel: int) -> void:
	if _selected_index < 0:
		return
	LD.get_scenario_handler().set_area(_selected_index, str(area_option.get_item_metadata(sel)))


func _on_show() -> void:
	_refresh_list()


func _on_hide() -> void:
	LD.get_scenario_handler().clear_editor_preview()


func _on_scenarios_changed() -> void:
	_refresh_list()


#region Scenario list

func _refresh_list() -> void:
	var prev: int = _selected_index
	_clear_rows()
	_add_list_row("COMMON", LDScenario.COMMON_INDEX)
	for scenario: LDScenario in LD.get_scenario_handler().get_numbered_scenarios():
		_add_list_row("Scenario %d" % scenario.index, scenario.index)
	
	for row: Button in _rows:
		if int(row.get_meta(INDEX_META)) == prev:
			row.button_pressed = true
			_show_detail(prev)
			return
	_show_detail(-1)


func _add_list_row(text: String, index: int) -> void:
	var row: Button = Button.new()
	row.text = text
	row.toggle_mode = true
	row.button_group = _row_group
	row.focus_mode = Control.FOCUS_NONE
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.set_meta(&"gdss_classes", PackedStringArray([ROW_CLASS]))
	row.set_meta(INDEX_META, index)
	row_container.add_child(row)
	row.pressed.connect(_on_scenario_row_pressed.bind(index))
	_rows.append(row)


func _clear_rows() -> void:
	for row: Button in _rows:
		row.button_group = null
		row_container.remove_child(row)
		row.queue_free()
	_rows.clear()


func _on_scenario_row_pressed(index: int) -> void:
	_show_detail(index)


func _on_add_pressed() -> void:
	var scenario: LDScenario = LD.get_scenario_handler().create_scenario()
	if scenario:
		_refresh_list()
		_select_index(scenario.index)


func _on_remove_pressed() -> void:
	if _selected_index > LDScenario.COMMON_INDEX:
		LD.get_scenario_handler().remove_scenario(_selected_index)


func _on_move_pressed(delta: int) -> void:
	if _selected_index <= LDScenario.COMMON_INDEX:
		return
	var new_index: int = LD.get_scenario_handler().move_scenario(_selected_index, delta)
	_refresh_list()
	_select_index(new_index)


func _select_index(index: int) -> void:
	for row: Button in _rows:
		if int(row.get_meta(INDEX_META)) == index:
			row.button_pressed = true
			_show_detail(index)
			return

#endregion


#region Detail

func _show_detail(index: int) -> void:
	_selected_index = index
	var has_scenario: bool = index >= 0
	empty_center.visible = not has_scenario
	detail_content.visible = has_scenario
	remove_button.disabled = index <= LDScenario.COMMON_INDEX
	GDSS.refresh(remove_button)
	# Name / shine-select only apply to numbered scenarios, not the COMMON baseline.
	var is_numbered: bool = index > LDScenario.COMMON_INDEX
	var ordered: Array[LDScenario] = LD.get_scenario_handler().get_numbered_scenarios()
	var order_pos: int = -1
	for i: int in ordered.size():
		if ordered[i].index == index:
			order_pos = i
			break
	move_up_button.disabled = not is_numbered or order_pos <= 0
	GDSS.refresh(move_up_button)
	move_down_button.disabled = not is_numbered or order_pos < 0 or order_pos >= ordered.size() - 1
	GDSS.refresh(move_down_button)
	shine_row.visible = is_numbered
	if is_numbered:
		var scenario: LDScenario = LD.get_scenario_handler().get_scenario(index)
		name_edit.text = scenario.display_name if scenario else ""
		shine_check.button_pressed = scenario.show_in_shine_select if scenario else true
	# Every scenario (including COMMON, which sets the default loaded area) picks an area.
	area_row.visible = has_scenario
	if has_scenario:
		_populate_area_options(LD.get_scenario_handler().get_scenario(index))
		_build_rows()
		LD.get_scenario_handler().apply_to_editor(index)
	else:
		LD.get_scenario_handler().clear_editor_preview()


## Fills the area dropdown with the level's areas and selects the scenario's linked one (defaulting
## to the first area when the scenario has no link yet).
func _populate_area_options(scenario: LDScenario) -> void:
	area_option.clear()
	var areas: Array[LDArea] = LD.get_level().get_areas()
	var selected: int = 0
	for i: int in areas.size():
		area_option.add_item(_area_label(areas[i], i))
		area_option.set_item_metadata(i, areas[i].area_name)
		if scenario and not scenario.area_name.is_empty() and scenario.area_name == areas[i].area_name:
			selected = i
	if area_option.item_count > 0:
		area_option.select(selected)


func _area_label(area: LDArea, index: int) -> String:
	return area.area_name if not area.area_name.is_empty() else "Area %d" % (index + 1)


func _build_rows() -> void:
	_clear_container(layers_container)
	_clear_container(tags_container)
	_clear_container(stamps_container)
	
	var sh: LDScenarioHandler = LD.get_scenario_handler()
	var scenario: LDScenario = sh.get_scenario(_selected_index)
	if not scenario:
		return
	var is_common: bool = _selected_index == LDScenario.COMMON_INDEX
	
	for layer: LDLayer in LD.get_area().layers:
		var layer_index: int = layer.index
		var opt: OptionButton = _make_row(layers_container, "Layer %d" % layer_index, is_common, scenario.get_layer_override(layer_index))
		opt.item_selected.connect(func(sel: int) -> void:
			sh.set_layer_override(_selected_index, layer_index, _state_from_id(opt.get_item_id(sel)))
			sh.apply_to_editor(_selected_index)
		)
	
	for tag: String in LD.get_tag_handler().get_all_tags():
		var opt2: OptionButton = _make_row(tags_container, tag, is_common, scenario.get_tag_override(tag))
		opt2.item_selected.connect(func(sel: int) -> void:
			sh.set_tag_override(_selected_index, tag, _state_from_id(opt2.get_item_id(sel)))
			sh.apply_to_editor(_selected_index)
		)
	
	for stamp: LDStamp in LD.get_stamp_handler().get_all_stamps():
		var stamp_id: String = stamp.id
		var opt3: OptionButton = _make_row(stamps_container, stamp_id, is_common, scenario.get_stamp_override(stamp_id))
		opt3.item_selected.connect(func(sel: int) -> void:
			sh.set_stamp_override(_selected_index, stamp_id, _state_from_id(opt3.get_item_id(sel)))
			sh.apply_to_editor(_selected_index)
		)
	
	layers_header.visible = layers_container.get_child_count() > 0
	tags_header.visible = tags_container.get_child_count() > 0
	stamps_header.visible = stamps_container.get_child_count() > 0


func _clear_container(parent: VBoxContainer) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _make_row(parent: VBoxContainer, text: String, is_common: bool, override: Variant) -> OptionButton:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label: Label = Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	
	var opt: OptionButton = OptionButton.new()
	opt.custom_minimum_size = Vector2(112, 28)
	opt.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if is_common:
		opt.add_item("Enabled", 1)
		opt.add_item("Disabled", 0)
		opt.select(0 if override == null or bool(override) else 1)
	else:
		opt.add_item("Inherit", 2)
		opt.add_item("Enabled", 1)
		opt.add_item("Disabled", 0)
		if override == null:
			opt.select(0)
		elif bool(override):
			opt.select(1)
		else:
			opt.select(2)
	row.add_child(opt)
	parent.add_child(row)
	return opt


func _state_from_id(id: int) -> Variant:
	match id:
		1:
			return true
		0:
			return false
	return null

#endregion
