class_name LDHotbarButton
extends Button


signal new_object_request(button: LDHotbarButton)


const SAVE_HOLD_DURATION: float = 3.0
const CLEAR_HOLD_DURATION: float = 1.0


var _slot_data: Array[Dictionary] = []
var _stamp_id: String = ""
var _hold_timer: float = 0.0
var _is_holding_left: bool = false
var _is_holding_right: bool = false


func _process(delta: float) -> void:
	if _is_holding_left:
		_hold_timer += delta
		if _hold_timer >= SAVE_HOLD_DURATION:
			_is_holding_left = false
			_hold_timer = 0.0
			_save_selection()
	
	elif _is_holding_right:
		_hold_timer += delta
		if _hold_timer >= CLEAR_HOLD_DURATION:
			_is_holding_right = false
			_hold_timer = 0.0
			_clear_slot()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_holding_left = true
				_hold_timer = 0.0
			else:
				if _is_holding_left:
					_is_holding_left = false
					if _hold_timer < SAVE_HOLD_DURATION:
						_on_click()
					_hold_timer = 0.0
		
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_is_holding_right = true
				_hold_timer = 0.0
			else:
				_is_holding_right = false
				_hold_timer = 0.0


func assign_object(game_object: GameObject) -> void:
	_stamp_id = ""
	var data: Dictionary = {
		"object_id": game_object.id,
		"position": [0.0, 0.0],
		"properties": {},
	}
	_slot_data = [data]
	_update_icon()


func assign_stamp(stamp_id: String) -> void:
	_slot_data = []
	_stamp_id = stamp_id
	_update_icon()


## Re-resolves the slot icon (e.g. after a stamp's preview finishes generating).
func refresh_icon() -> void:
	_update_icon()


func serialize() -> Dictionary:
	return {
		"stamp_id": _stamp_id,
		"slot_data": _slot_data.duplicate(true),
	}


func deserialize(data: Dictionary) -> void:
	_stamp_id = str(data.get("stamp_id", ""))
	var slots: Array[Dictionary] = []
	for entry: Variant in data.get("slot_data", []):
		if entry is Dictionary:
			slots.append(entry)
	_slot_data = slots
	_update_icon()


func _on_click() -> void:
	if not _stamp_id.is_empty():
		var stamp: LDStamp = LD.get_stamp_handler().get_stamp(_stamp_id)
		if stamp:
			LD.get_stamp_handler().arm_stamp(stamp)
			LD.get_tool_handler().select_tool("place")
			return
		# Stamp was deleted; fall back to picking a new assignment.
		_clear_slot()

	if _slot_data.is_empty():
		new_object_request.emit(self)
		return

	if _slot_data.size() == 1:
		var game_object: GameObject = GameDB.get_db().find_game_object(_slot_data.front().get("object_id", ""))
		if game_object:
			LD.get_object_handler().select_object(game_object)
			LD.get_tool_handler().select_tool("brush")
			return

	LD.get_clipboard_handler().paste_offset()


func _save_selection() -> void:
	var selection: Array[LDObject] = LD.get_object_handler().get_placed_selection()
	if selection.is_empty():
		return
	
	var save_load: LDSaveLoadHandler = LD.get_save_load_handler()
	var temp: Array[Dictionary] = []
	for obj: LDObject in selection:
		var data: Dictionary = save_load._serialize_object(obj)
		if not data.is_empty():
			temp.append(data)
	
	if temp.is_empty():
		return

	_stamp_id = ""
	_slot_data = temp
	_update_icon()


func _clear_slot() -> void:
	_slot_data.clear()
	_stamp_id = ""
	_update_icon()


func _update_icon() -> void:
	if not _stamp_id.is_empty():
		var stamp: LDStamp = LD.get_stamp_handler().get_stamp(_stamp_id)
		icon = stamp.preview_texture if stamp else null
		return

	if _slot_data.is_empty():
		icon = null
		return

	if _slot_data.size() == 1:
		var game_object: GameObject = GameDB.get_db().find_game_object(_slot_data.front().get("object_id", ""))
		if game_object:
			icon = game_object.ld_entry_texture
			return

	icon = null
