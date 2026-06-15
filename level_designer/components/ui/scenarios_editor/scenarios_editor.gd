class_name LDScenarioEditor
extends MarginContainer

## Editor for the level's scenarios. Left = scenario list (COMMON pinned first, plus
## numbered scenarios). Right = per-scenario toggles for every layer and tag.
## COMMON rows are Enabled/Disabled (the baseline); numbered scenarios are
## Inherit/Enabled/Disabled overrides on top of COMMON. Mirrors stamps_editor.gd.


@export var scenario_list: ItemList
@export var add_button: Button
@export var remove_button: Button
@export var empty_label: Label
@export var detail_content: Control
@export var shine_row: HBoxContainer
@export var name_edit: LineEdit
@export var shine_check: CheckButton
@export var layers_container: VBoxContainer
@export var tags_container: VBoxContainer
@export var stamps_container: VBoxContainer


var _selected_index: int = -1


func _ready() -> void:
	add_button.pressed.connect(_on_add_pressed)
	remove_button.pressed.connect(_on_remove_pressed)
	scenario_list.item_selected.connect(_on_scenario_selected)

	name_edit.text_changed.connect(_on_name_changed)
	shine_check.toggled.connect(_on_shine_toggled)

	var sh: LDScenarioHandler = LD.get_scenario_handler()
	sh.scenario_added.connect(_on_scenarios_changed.unbind(1))
	sh.scenario_removed.connect(_on_scenarios_changed.unbind(1))

	_refresh_list()


func _on_name_changed(text: String) -> void:
	if _selected_index > LDScenario.COMMON_INDEX:
		LD.get_scenario_handler().set_display_name(_selected_index, text)


func _on_shine_toggled(pressed: bool) -> void:
	if _selected_index > LDScenario.COMMON_INDEX:
		LD.get_scenario_handler().set_show_in_shine_select(_selected_index, pressed)


func _on_show() -> void:
	_refresh_list()


func _on_hide() -> void:
	LD.get_scenario_handler().clear_editor_preview()


func _on_scenarios_changed() -> void:
	_refresh_list()


func _refresh_list() -> void:
	var prev: int = _selected_index
	scenario_list.clear()
	scenario_list.add_item("COMMON")
	scenario_list.set_item_metadata(scenario_list.item_count - 1, LDScenario.COMMON_INDEX)
	for scenario: LDScenario in LD.get_scenario_handler().get_numbered_scenarios():
		scenario_list.add_item("Scenario %d" % scenario.index)
		scenario_list.set_item_metadata(scenario_list.item_count - 1, scenario.index)

	for i: int in scenario_list.item_count:
		if int(scenario_list.get_item_metadata(i)) == prev:
			scenario_list.select(i)
			_show_detail(prev)
			return
	_show_detail(-1)


func _on_scenario_selected(idx: int) -> void:
	_show_detail(int(scenario_list.get_item_metadata(idx)))


func _on_add_pressed() -> void:
	var scenario: LDScenario = LD.get_scenario_handler().create_scenario()
	if scenario:
		_refresh_list()
		_select_index(scenario.index)


func _on_remove_pressed() -> void:
	if _selected_index > LDScenario.COMMON_INDEX:
		LD.get_scenario_handler().remove_scenario(_selected_index)


func _select_index(index: int) -> void:
	for i: int in scenario_list.item_count:
		if int(scenario_list.get_item_metadata(i)) == index:
			scenario_list.select(i)
			_show_detail(index)
			return


func _show_detail(index: int) -> void:
	_selected_index = index
	var has_scenario: bool = index >= 0
	empty_label.visible = not has_scenario
	detail_content.visible = has_scenario
	remove_button.disabled = index <= LDScenario.COMMON_INDEX
	# Name / shine-select only apply to numbered scenarios, not the COMMON baseline.
	var is_numbered: bool = index > LDScenario.COMMON_INDEX
	shine_row.visible = is_numbered
	if is_numbered:
		var scenario: LDScenario = LD.get_scenario_handler().get_scenario(index)
		name_edit.text = scenario.display_name if scenario else ""
		shine_check.button_pressed = scenario.show_in_shine_select if scenario else true
	if has_scenario:
		_build_rows()
		LD.get_scenario_handler().apply_to_editor(index)
	else:
		LD.get_scenario_handler().clear_editor_preview()


func _build_rows() -> void:
	for child: Node in layers_container.get_children():
		child.queue_free()
	for child: Node in tags_container.get_children():
		child.queue_free()
	for child: Node in stamps_container.get_children():
		child.queue_free()

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


func _make_row(parent: VBoxContainer, text: String, is_common: bool, override: Variant) -> OptionButton:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var opt: OptionButton = OptionButton.new()
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
