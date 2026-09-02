class_name LDUIHotbarHandler
extends Node

## Owns the object hotbar. The slots themselves are plain data ([LDHotbarSlot]) held here; the
## buttons are views onto them, so reordering, key bindings and the active highlight are all
## decided in one place. When a slot asks for a new object it opens the object browser, then
## assigns whatever the user picks back to that slot. Reached via LD.get_ui().get_hotbar_handler().


const SLOT_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8]


@export var _hotbar_buttons: Array[LDHotbarButton]


var _slots: Array[LDHotbarSlot] = []
var _pending_index: int = -1


## Called by LDUI once the level designer is fully ready.
func setup() -> void:
	for i: int in _hotbar_buttons.size():
		_slots.append(LDHotbarSlot.new())
		var button: LDHotbarButton = _button_at(i)
		button.bind(i, _slots.get(i))
		button.activate_requested.connect(activate_slot)
		button.assign_requested.connect(assign_selection)
		button.clear_requested.connect(clear_slot)
		button.move_requested.connect(swap_slots)
	
	# The browser is built on first open, so wire onto it when it appears rather than
	# forcing it into existence here.
	var windows: LDUIWindowHandler = LD.get_ui().get_window_handler()
	windows.content_created.connect(_on_window_content_created)
	windows.active_changed.connect(_on_active_window_changed)
	
	# Stamp previews generate asynchronously, so refresh stamp-slot icons when they change.
	var stamps: LDStampHandler = LD.get_stamp_handler()
	stamps.stamp_changed.connect(_on_stamps_changed.unbind(1))
	stamps.stamp_removed.connect(_on_stamps_changed.unbind(1))
	stamps.armed_stamp_changed.connect(_refresh_active.unbind(1))
	LD.get_object_handler().selected_object_changed.connect(_refresh_active.unbind(1))


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or LD.has_input_capture():
		return
	if key.is_command_or_control_pressed() or key.alt_pressed:
		return
	
	var index: int = SLOT_KEYS.find(key.keycode)
	if index < 0 or index >= _slots.size():
		return
	
	if key.shift_pressed:
		assign_selection(index)
	else:
		activate_slot(index)
	get_viewport().set_input_as_handled()


#region Slot actions

## Uses slot `index`: paints its object, arms its stamp or group, or - when the slot is empty -
## opens the browser to fill it.
func activate_slot(index: int) -> void:
	var slot: LDHotbarSlot = _slot_at(index)
	if not slot:
		return
	if not slot.is_valid():
		slot.clear()
		_refresh(index)
	
	var stamps: LDStampHandler = LD.get_stamp_handler()
	match slot.kind:
		LDHotbarSlot.Kind.EMPTY:
			_pending_index = index
			_refresh_active()
			LD.get_ui().get_window_handler().open(LDUIWindowHandler.OBJECT_BROWSER)
		LDHotbarSlot.Kind.OBJECT:
			var obj: GameObject = GameDB.get_object(slot.object_id)
			stamps.arm_stamp(null)
			LD.get_object_handler().select_object(obj)
			var placement: String = obj.get_placement_tool()
			LD.get_tool_handler().select_tool(placement if not placement.is_empty() else "brush")
		LDHotbarSlot.Kind.STAMP:
			stamps.arm_stamp(stamps.get_stamp(slot.stamp_id))
			LD.get_tool_handler().select_tool("place")
		LDHotbarSlot.Kind.GROUP:
			stamps.arm_stamp(slot.group)
			LD.get_tool_handler().select_tool("place")


## Snapshots the placed selection into slot `index`. Captures are always groups, however few
## objects they hold, so the properties and polygon data of what was picked survive.
func assign_selection(index: int) -> void:
	var slot: LDHotbarSlot = _slot_at(index)
	if not slot:
		return
	var stamps: LDStampHandler = LD.get_stamp_handler()
	var group: LDStamp = stamps.build_loose_stamp(LD.get_object_handler().get_placed_selection())
	if not group:
		return
	
	slot.set_group(group)
	_refresh(index)
	_button_at(index).play_landed()
	_persist()
	
	await stamps.generate_preview(group)
	if slot.group == group:
		_refresh(index)


func clear_slot(index: int) -> void:
	var slot: LDHotbarSlot = _slot_at(index)
	if not slot or slot.is_empty():
		return
	var stamps: LDStampHandler = LD.get_stamp_handler()
	if slot.kind == LDHotbarSlot.Kind.GROUP and stamps.get_armed_stamp() == slot.group:
		stamps.arm_stamp(null)
	
	slot.clear()
	_refresh(index)
	_button_at(index).play_cleared()
	_refresh_active()
	_persist()


func swap_slots(from_index: int, to_index: int) -> void:
	if not _slot_at(from_index) or not _slot_at(to_index) or from_index == to_index:
		return
	var moved: LDHotbarSlot = _slots.get(from_index)
	_slots.set(from_index, _slots.get(to_index))
	_slots.set(to_index, moved)
	_refresh(from_index)
	_refresh(to_index)
	_button_at(to_index).play_landed()
	_refresh_active()
	_persist()

#endregion


#region Persistence

func serialize_slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot: LDHotbarSlot in _slots:
		result.append(slot.serialize())
	return result


func deserialize_slots(data: Array) -> void:
	for i: int in _slots.size():
		var entry: Variant = data.get(i) if i < data.size() else null
		var stored: Dictionary = entry if entry is Dictionary else {}
		_slots.set(i, LDHotbarSlot.deserialize(stored))
		_refresh(i)
	_refresh_active()
	_build_group_previews()


func _build_group_previews() -> void:
	var stamps: LDStampHandler = LD.get_stamp_handler()
	for i: int in _slots.size():
		var slot: LDHotbarSlot = _slots.get(i)
		if slot.kind != LDHotbarSlot.Kind.GROUP:
			continue
		var group: LDStamp = slot.group
		await stamps.generate_preview(group)
		if slot.group == group:
			_refresh(i)


func _persist() -> void:
	LD.get_save_load_handler().save_session()

#endregion


#region Internal

func _slot_at(index: int) -> LDHotbarSlot:
	return _slots.get(index) if index >= 0 and index < _slots.size() else null


func _button_at(index: int) -> LDHotbarButton:
	return _hotbar_buttons.get(index) as LDHotbarButton


func _refresh(index: int) -> void:
	_button_at(index).bind(index, _slots.get(index))


func _refresh_active() -> void:
	var armed: LDStamp = LD.get_stamp_handler().get_armed_stamp()
	var selected: GameObject = LD.get_object_handler().get_selected_object()
	for i: int in _slots.size():
		var active: bool = i == _pending_index if _pending_index >= 0 else _is_armed(_slots.get(i), armed, selected)
		_button_at(i).set_active(active)


func _is_armed(slot: LDHotbarSlot, armed: LDStamp, selected: GameObject) -> bool:
	match slot.kind:
		LDHotbarSlot.Kind.STAMP:
			return armed != null and armed.id == slot.stamp_id
		LDHotbarSlot.Kind.GROUP:
			return armed != null and armed == slot.group
		LDHotbarSlot.Kind.OBJECT:
			return armed == null and selected != null and selected.id == slot.object_id
	return false


func _on_window_content_created(id: StringName, content: Control) -> void:
	if id == LDUIWindowHandler.OBJECT_BROWSER:
		(content as LDObjectBrowser).hide_request.connect(_on_browser_hide_request)


## Leaving the browser any other way than by picking something drops the slot that asked, so a
## later unrelated pick cannot land in it.
func _on_active_window_changed(id: StringName) -> void:
	if id == LDUIWindowHandler.OBJECT_BROWSER or _pending_index < 0:
		return
	_pending_index = -1
	_refresh_active()


func _on_stamps_changed() -> void:
	for i: int in _slots.size():
		_refresh(i)
	_refresh_active()


func _on_browser_hide_request() -> void:
	LD.get_ui().get_window_handler().close()
	
	var index: int = _pending_index
	_pending_index = -1
	if index < 0:
		return
	
	# A stamp pick arms a stamp; an object pick clears it. Check the stamp first.
	var slot: LDHotbarSlot = _slots.get(index)
	var stamp: LDStamp = LD.get_stamp_handler().get_armed_stamp()
	if stamp:
		slot.set_stamp(stamp.id)
	else:
		var selected: GameObject = LD.get_object_handler().get_selected_object()
		if not selected:
			_refresh_active()
			return
		slot.set_object(selected.id)
	
	_refresh(index)
	_button_at(index).play_landed()
	_refresh_active()
	_persist()

#endregion
