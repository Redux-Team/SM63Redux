class_name LDHotbar
extends LDComponent

const STATE_KEY: String = "hotbar"

@export var slots: Array[LDHotbarSlot]

var _ids: Array[StringName] = []
var _assigning: int = -1


func _setup() -> void:
	_ids.resize(slots.size())
	_ids.fill(&"")
	for i: int in slots.size():
		var slot: LDHotbarSlot = slots.get(i)
		slot.index = i
		slot.tapped.connect(func(tapped: LDHotbarSlot) -> void: activate(tapped.index))
		slot.held.connect(func(held: LDHotbarSlot) -> void: clear_slot(held.index))
		slot.moved.connect(move_slot)
	
	editor.level_handler.level_opened.connect(_load)
	editor.tool_handler.armed_changed.connect(_refresh.unbind(1))
	editor.object_handler.browser.picked.connect(_on_picked)
	editor.interface_handler.panel_changed.connect(func(panel: LDPanel) -> void:
		if panel == null:
			_assigning = -1)
	_load()


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


func activate(index: int) -> void:
	var entry: ObjectRegistry.Entry = ObjectRegistry.get_entry(_ids.get(index))
	if entry == null:
		_assigning = index
		editor.object_handler.browser.open()
		return
	
	SFX.play(SFX.LD_SELECT)
	editor.tool_handler.arm(entry)


func assign(index: int, entry: ObjectRegistry.Entry) -> void:
	if entry == null:
		return
	
	_ids.set(index, entry.id)
	_save()


func clear_slot(index: int) -> void:
	if _ids.get(index).is_empty():
		return
	
	SFX.play(SFX.LD_BACK)
	_ids.set(index, &"")
	_save()


func move_slot(from: int, to: int) -> void:
	var id: StringName = _ids.get(from)
	_ids.set(from, _ids.get(to))
	_ids.set(to, id)
	_save()


func cycle(direction: int) -> void:
	var filled: Array[int] = []
	for i: int in _ids.size():
		if ObjectRegistry.get_entry(_ids.get(i)):
			filled.append(i)
	
	if filled.is_empty():
		return
	
	var armed: ObjectRegistry.Entry = editor.tool_handler.armed
	var current: int = filled.find(_ids.find(armed.id) if armed else -1)
	var next: int = posmod(current + direction, filled.size()) if current >= 0 else 0
	activate(filled.get(next))


func _on_picked(entry: ObjectRegistry.Entry) -> void:
	if _assigning >= 0:
		assign(_assigning, entry)
		_assigning = -1


func _load() -> void:
	var saved: Array = editor.level_handler.editor_state.get(STATE_KEY, [])
	for i: int in _ids.size():
		_ids.set(i, StringName(saved.get(i)) if i < saved.size() else &"")
	_refresh()


func _save() -> void:
	var saved: Array[String] = []
	for id: StringName in _ids:
		saved.append(String(id))
	editor.level_handler.editor_state.set(STATE_KEY, saved)
	_refresh()


func _refresh() -> void:
	var armed: ObjectRegistry.Entry = editor.tool_handler.armed
	for i: int in slots.size():
		var slot: LDHotbarSlot = slots.get(i)
		var entry: ObjectRegistry.Entry = ObjectRegistry.get_entry(_ids.get(i))
		slot.icon = entry.get_icon() if entry else null
		Tooltip.set_text(slot, "%s (%d)" % [entry.display_name, i + 1] if entry else "Empty slot (%d)" % (i + 1), Tooltip.Placement.ABOVE)
		LD.set_active(slot, entry != null and entry == armed)
