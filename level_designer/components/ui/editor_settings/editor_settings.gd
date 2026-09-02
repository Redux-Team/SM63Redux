class_name LDEditorSettings
extends MarginContainer

## A deliberately plain settings panel for the level designer, built straight from [Settings] with
## no styling of its own. It exists so the settings system stays reachable while the UI is being
## redesigned - expect it to be replaced wholesale by the new design.


const ROW_HEIGHT: float = 24.0
const CONTROL_WIDTH: float = 160.0


@export var rows_container: VBoxContainer
@export var scroll_container: ScrollContainer


func _ready() -> void:
	Settings.bus.changed.connect(_on_setting_changed)
	_rebuild()


## Rebuilt on show so rows reflect anything changed elsewhere, and so device-dependent settings
## appear or disappear with the active input.
func _on_show() -> void:
	_rebuild()


func _rebuild() -> void:
	for child: Node in rows_container.get_children():
		rows_container.remove_child(child)
		child.queue_free()

	for section: StringName in Settings.get_sections():
		_add_heading(SettingsCatalog.get_section_label(section))
		for def: SettingDef in Settings.get_section_defs(section):
			_add_row(def)

	_add_reset_button()
	scroll_container.set_deferred(&"scroll_vertical", 0)


func _add_reset_button() -> void:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 12.0)
	rows_container.add_child(spacer)

	var button: Button = Button.new()
	button.text = "Reset All to Defaults"
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void:
		Settings.reset_all()
		_rebuild()
	)
	rows_container.add_child(button)


func _add_heading(text: String) -> void:
	var heading: Label = Label.new()
	heading.text = text
	heading.custom_minimum_size = Vector2(0.0, 26.0)
	heading.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	rows_container.add_child(heading)


func _add_row(def: SettingDef) -> void:
	var control: Control = _build_control(def)
	if not control:
		return

	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)

	var label: Label = Label.new()
	label.text = def.label
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.tooltip_text = def.description
	row.add_child(label)

	control.custom_minimum_size = Vector2(CONTROL_WIDTH, 0.0)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	rows_container.add_child(row)


func _build_control(def: SettingDef) -> Control:
	match def.type:
		SettingDef.Type.BOOL:
			return _build_toggle(def)
		SettingDef.Type.SLIDER:
			return _build_slider(def)
		SettingDef.Type.CHOICE:
			return _build_choice(def)
		SettingDef.Type.KEYBIND:
			return _build_keybind(def)
	return null


## A CheckButton rather than a CheckBox: the project theme blanks CheckBox's state icons, which
## leaves it invisible under the editor's stylesheet, while CheckButton falls through to Godot's
## own switch graphics.
func _build_toggle(def: SettingDef) -> Control:
	var check: CheckButton = CheckButton.new()
	check.set_pressed_no_signal(Settings.get_bool(def.key))
	check.toggled.connect(func(pressed: bool) -> void: Settings.set_value(def.key, pressed))
	return check


## The readout always tracks the handle. Whether the value is written as it moves or only once the
## handle is let go is the setting's own call - see [member SettingDef.apply_on_release], which UI
## scaling uses so the whole interface is not resized on every intermediate value.
func _build_slider(def: SettingDef) -> Control:
	var row: HBoxContainer = HBoxContainer.new()

	var value_label: Label = Label.new()
	value_label.custom_minimum_size = Vector2(56.0, 0.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = def.format_value(Settings.get_float(def.key))

	var slider: HSlider = HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.min_value = def.minimum
	slider.max_value = def.maximum
	slider.step = def.step if def.step > 0.0 else 0.01
	slider.set_value_no_signal(Settings.get_float(def.key))

	# Boxed so the lambdas below share one flag rather than each capturing their own copy.
	var dragging: Array[bool] = [false]

	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = def.format_value(value)
		if not (def.apply_on_release and dragging.get(0)):
			Settings.set_value(def.key, value)
	)
	slider.drag_started.connect(func() -> void: dragging.set(0, true))
	# drag_ended reports whether the value moved, not what it moved to.
	slider.drag_ended.connect(func(value_changed: bool) -> void:
		dragging.set(0, false)
		if value_changed:
			Settings.set_value(def.key, slider.value)
	)

	row.add_child(slider)
	row.add_child(value_label)
	return row


func _build_choice(def: SettingDef) -> Control:
	var options: Dictionary[String, Variant] = def.get_choices()
	var values: Array = options.values()

	var dropdown: OptionButton = OptionButton.new()
	dropdown.clip_text = true
	for option_label: String in options:
		dropdown.add_item(option_label)

	var index: int = values.find(Settings.get_value(def.key))
	if index >= 0:
		dropdown.select(index)

	dropdown.item_selected.connect(func(selected: int) -> void: Settings.set_value(def.key, values.get(selected)))
	return dropdown


## Click to listen for the next key or pad input, right-click to clear. No frills: the redesign
## will decide how rebinding should actually look.
func _build_keybind(def: SettingDef) -> Control:
	var action: StringName = StringName(def.get_entry())
	var button: Button = Button.new()
	button.clip_text = true
	button.text = ControlScheme.describe_action(action)
	button.tooltip_text = "Click to add a binding, right-click to clear"

	var listening: Array[bool] = [false]
	button.pressed.connect(func() -> void:
		listening.set(0, true)
		button.text = "..."
	)
	button.gui_input.connect(func(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click and click.button_index == MOUSE_BUTTON_RIGHT and not click.pressed:
			ControlScheme.clear(action)
	)
	# Listening happens on the panel's own input so the press that armed it cannot bind itself.
	button.set_meta(&"action", action)
	button.set_meta(&"listening", listening)
	return button


func _input(event: InputEvent) -> void:
	for button: Button in _listening_buttons():
		if event.is_action_pressed(&"ui_cancel") or ControlScheme.is_bindable(event):
			accept_event()
			if not event.is_action_pressed(&"ui_cancel"):
				ControlScheme.add_event(button.get_meta(&"action"), event)
			(button.get_meta(&"listening") as Array[bool]).set(0, false)
			button.text = ControlScheme.describe_action(button.get_meta(&"action"))
			return


func _keybind_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for row: Node in rows_container.get_children():
		for child: Node in row.get_children():
			var button: Button = child as Button
			if button and button.has_meta(&"action"):
				result.append(button)
	return result


func _listening_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for button: Button in _keybind_buttons():
		if (button.get_meta(&"listening") as Array[bool]).get(0):
			result.append(button)
	return result


## Bindings refresh their own button rather than rebuilding the list: a rebuild would throw away
## the scroll position, dropping the player back at the top every time they rebound something.
func _on_setting_changed(key: StringName, _value: Variant) -> void:
	if not String(key).begins_with("controls/"):
		return

	for button: Button in _keybind_buttons():
		button.text = ControlScheme.describe_action(button.get_meta(&"action"))
