class_name LDHotbar
extends LDComponent

const STATE_KEY: String = "hotbar"
const VALUES_KEY: String = "hotbar_values"

@export var slots: Array[LDHotbarSlot]
@export var placement_panel: LDPlacementPanel

var _ids: Array[StringName] = []
var _values: Array[Dictionary] = []
var _assigning: int = -1


func _unhandled_input(event: InputEvent) -> void:
	if not editor.accepts_shortcuts():
		return
	
	if event.is_action_pressed(&"ld_hotbar_next") or event.is_action_pressed(&"ld_hotbar_previous"):
		cycle(1 if event.is_action(&"ld_hotbar_next") else -1)
		get_viewport().set_input_as_handled()
		return
	
	for i: int in slots.size():
		if event.is_action_pressed(StringName("ld_hotbar_%d" % (i + 1))):
			var key: InputEventKey = event as InputEventKey
			if key and key.shift_pressed:
				assign(i, editor.tool_handler.armed)
			else:
				activate(i)
			get_viewport().set_input_as_handled()
			return


func _setup() -> void:
	_ids.resize(slots.size())
	_ids.fill(&"")
	_values.resize(slots.size())
	for i: int in slots.size():
		var slot: LDHotbarSlot = slots[i]
		slot.index = i
		slot.tapped.connect(func(tapped: LDHotbarSlot) -> void: activate(tapped.index))
		slot.held.connect(func(held: LDHotbarSlot) -> void: clear_slot(held.index))
		slot.gui_input.connect(_on_slot_input.bind(i))
	
	editor.level_handler.level_opened.connect(_load)
	editor.tool_handler.armed_changed.connect(_refresh.unbind(1))
	editor.object_handler.browser.picked.connect(_on_picked)
	editor.interface_handler.panel_changed.connect(func(panel: LDPanel) -> void:
			if panel == null:
				_assigning = -1)
	_load()


func activate(index: int) -> void:
	var entry: ObjectRegistry.Entry = ObjectRegistry.get_entry(_ids[index])
	if entry == null:
		_assigning = index
		editor.object_handler.browser.open()
		return
	
	editor.tool_handler.arm(entry, _values[index])


func assign(index: int, entry: ObjectRegistry.Entry) -> void:
	if entry == null:
		return
	
	if _ids[index] != entry.id:
		_values[index] = {}
	_ids[index] = entry.id
	_save()


func clear_slot(index: int) -> void:
	if _ids[index].is_empty():
		return
	
	SFX.play(SFX.LD_BACK)
	_ids[index] = &""
	_values[index] = {}
	_save()


func cycle(direction: int) -> void:
	var filled: Array[int] = []
	for i: int in _ids.size():
		if ObjectRegistry.get_entry(_ids[i]):
			filled.append(i)
	
	if filled.is_empty():
		return
	
	var armed: ObjectRegistry.Entry = editor.tool_handler.armed
	var current: int = filled.find(_ids.find(armed.id) if armed else -1)
	var next: int = posmod(current + direction, filled.size()) if current >= 0 else 0
	activate(filled[next])


func edit_slot(index: int) -> void:
	var entry: ObjectRegistry.Entry = ObjectRegistry.get_entry(_ids[index])
	if entry == null:
		return
	
	placement_panel.edit(entry, _values[index], _save)


func _on_slot_input(event: InputEvent, index: int) -> void:
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button and mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
		edit_slot(index)
		slots[index].accept_event()


func _on_picked(entry: ObjectRegistry.Entry) -> void:
	if _assigning >= 0:
		assign(_assigning, entry)
		_assigning = -1


func _load() -> void:
	var saved: Array = editor.level_handler.editor_state.get(STATE_KEY, [])
	var saved_values: Array = editor.level_handler.editor_state.get(VALUES_KEY, [])
	for i: int in _ids.size():
		_ids[i] = StringName(saved[i]) if i < saved.size() else &""
		_values[i] = (
				(saved_values[i] as Dictionary).duplicate()
				if i < saved_values.size() and saved_values[i] is Dictionary
				else {}
		)
	_refresh()


func _save() -> void:
	var saved: Array[String] = []
	for id: StringName in _ids:
		saved.append(String(id))
	editor.level_handler.editor_state[STATE_KEY] = saved
	editor.level_handler.editor_state[VALUES_KEY] = _values.duplicate(true)
	_refresh()


func _refresh() -> void:
	var armed: ObjectRegistry.Entry = editor.tool_handler.armed
	for i: int in slots.size():
		var slot: LDHotbarSlot = slots[i]
		var entry: ObjectRegistry.Entry = ObjectRegistry.get_entry(_ids[i])
		slot.icon = entry.get_icon(_values[i]) if entry else null
		var custom: String = (
				"\nCustom placement (right-click to edit)"
				if entry and not _values[i].is_empty()
				else ""
		)
		var key: int = (i + 1) % 10
		Tooltip.set_text(
				slot,
				(
						"%s (%d)%s" % [entry.display_name, key, custom]
						if entry
						else "Empty slot (%d)" % key
				),
				Tooltip.Placement.ABOVE,
		)
		LD.set_active(slot, entry != null and entry == armed)
