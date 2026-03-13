class_name LDSelectionShortcutHandler
extends Node

# TODO: use InputAction events

var _viewport: LDViewport:
	get:
		return LD.get_editor_viewport()


func handle_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.echo:
		return
	
	var ctrl: bool = event.is_command_or_control_pressed()
	var shift: bool = event.shift_pressed
	var alt: bool = event.alt_pressed
	
	if ctrl and shift and event.keycode == KEY_H:
		align_horizontal()
	
	if ctrl and alt and event.keycode == KEY_V:
		if shift:
			align_vertical_spaced()
		else:
			align_vertical()
	
	if ctrl and event.keycode == KEY_D:
		duplicate_selection()
	
	if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
		delete_selection()
	
	if ctrl and event.keycode == KEY_G:
		snap_to_grid()
	
	if ctrl and alt and event.keycode == KEY_C:
		if shift:
			distribute_centered()
		else:
			center_on_centroid()
	
	if ctrl and event.keycode == KEY_R:
		if shift:
			flip_vertical()
		else:
			flip_horizontal()


func align_horizontal() -> void:
	var objects: Array[LDObject] = _viewport.get_selected_objects()
	if objects.is_empty():
		return
	
	var avg_y: float = 0.0
	for obj: LDObject in objects:
		avg_y += obj.position.y
	avg_y = snappedf(avg_y / objects.size(), LDViewport.SNAPPING_SIZE)
	
	var old_positions: Array[Vector2] = []
	for obj: LDObject in objects:
		old_positions.append(obj.position)
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Align Horizontal")
	history.add_do(func() -> void:
		for i: int in objects.size():
			if is_instance_valid(objects[i]):
				objects[i].position.y = avg_y
	)
	history.add_undo(func() -> void:
		for i: int in objects.size():
			if is_instance_valid(objects[i]):
				objects[i].position = old_positions[i]
	)
	history.commit_action()
	
	for obj: LDObject in objects:
		obj.position.y = avg_y


func align_horizontal_spaced() -> void:
	var objects: Array[LDObject] = _viewport.get_selected_objects()
	if objects.is_empty():
		return
	
	objects.sort_custom(func(a: LDObject, b: LDObject) -> bool:
		return a.position.x < b.position.x
	)
	
	var avg_y: float = 0.0
	for obj: LDObject in objects:
		avg_y += obj.position.y
	avg_y = snappedf(avg_y / objects.size(), LDViewport.SNAPPING_SIZE)
	
	var start_x: float = objects.front().position.x
	var stamp_size: float = objects.front().get_stamp_size().x
	
	var old_positions: Array[Vector2] = []
	var new_positions: Array[Vector2] = []
	for i: int in objects.size():
		old_positions.append(objects[i].position)
		new_positions.append(Vector2(snappedf(start_x + i * stamp_size, LDViewport.SNAPPING_SIZE), avg_y))
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Align Horizontal Spaced")
	history.add_do(func() -> void:
		for i: int in objects.size():
			if is_instance_valid(objects[i]):
				objects[i].position = new_positions[i]
	)
	history.add_undo(func() -> void:
		for i: int in objects.size():
			if is_instance_valid(objects[i]):
				objects[i].position = old_positions[i]
	)
	history.commit_action()
	
	for i: int in objects.size():
		objects[i].position = new_positions[i]


func align_vertical() -> void:
	var objects: Array[LDObject] = _viewport.get_selected_objects()
	if objects.is_empty():
		return
	
	var avg_x: float = 0.0
	for obj: LDObject in objects:
		avg_x += obj.position.x
	avg_x = snappedf(avg_x / objects.size(), LDViewport.SNAPPING_SIZE)
	
	var old_positions: Array[Vector2] = []
	for obj: LDObject in objects:
		old_positions.append(obj.position)
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Align Vertical")
	history.add_do(func() -> void:
		for i: int in objects.size():
			if is_instance_valid(objects[i]):
				objects[i].position.x = avg_x
	)
	history.add_undo(func() -> void:
		for i: int in objects.size():
			if is_instance_valid(objects[i]):
				objects[i].position = old_positions[i]
	)
	history.commit_action()
	
	for obj: LDObject in objects:
		obj.position.x = avg_x


func align_vertical_spaced() -> void:
	var objects: Array[LDObject] = _viewport.get_selected_objects()
	if objects.is_empty():
		return
	
	objects.sort_custom(func(a: LDObject, b: LDObject) -> bool:
		return a.position.y < b.position.y
	)
	
	var avg_x: float = 0.0
	for obj: LDObject in objects:
		avg_x += obj.position.x
	avg_x = snappedf(avg_x / objects.size(), LDViewport.SNAPPING_SIZE)
	
	var start_y: float = objects.front().position.y
	var stamp_size: float = objects.front().get_stamp_size().y
	
	var old_positions: Array[Vector2] = []
	var new_positions: Array[Vector2] = []
	for i: int in objects.size():
		old_positions.append(objects[i].position)
		new_positions.append(Vector2(avg_x, snappedf(start_y + i * stamp_size, LDViewport.SNAPPING_SIZE)))
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Align Vertical Spaced")
	history.add_do(func() -> void:
		for i: int in objects.size():
			if is_instance_valid(objects[i]):
				objects[i].position = new_positions[i]
	)
	history.add_undo(func() -> void:
		for i: int in objects.size():
			if is_instance_valid(objects[i]):
				objects[i].position = old_positions[i]
	)
	history.commit_action()
	
	for i: int in objects.size():
		objects[i].position = new_positions[i]


func duplicate_selection() -> void:
	var objects: Array[LDObject] = _viewport.get_selected_objects()
	if objects.is_empty():
		return
	
	var duplicates: Array[LDObject] = []
	for obj: LDObject in objects:
		var dupe: LDObject = obj.duplicate() as LDObject
		_viewport.add_object(dupe, Vector2i(obj.position + Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE)))
		dupe.place()
		duplicates.append(dupe)
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Duplicate Objects")
	history.add_do(func() -> void:
		for dupe: LDObject in duplicates:
			if is_instance_valid(dupe):
				dupe.show()
	)
	history.add_undo(func() -> void:
		for dupe: LDObject in duplicates:
			if is_instance_valid(dupe):
				dupe.hide()
	)
	history.commit_action()
	
	_viewport.set_selected_objects(duplicates)


func delete_selection() -> void:
	var objects: Array[LDObject] = _viewport.get_selected_objects()
	if objects.is_empty():
		return
	
	_viewport.clear_selection()
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Delete Objects")
	history.add_do(func() -> void:
		for obj: LDObject in objects:
			if is_instance_valid(obj):
				obj.hide()
	)
	history.add_undo(func() -> void:
		for obj: LDObject in objects:
			if is_instance_valid(obj):
				obj.show()
	)
	history.commit_action()
	
	for obj: LDObject in objects:
		obj.hide()


func snap_to_grid() -> void:
	var objects: Array[LDObject] = _viewport.get_selected_objects()
	if objects.is_empty():
		return
	
	var old_positions: Array[Vector2] = []
	var new_positions: Array[Vector2] = []
	for obj: LDObject in objects:
		old_positions.append(obj.position)
		new_positions.append(Vector2(
			snappedf(obj.position.x, LDViewport.SNAPPING_SIZE),
			snappedf(obj.position.y, LDViewport.SNAPPING_SIZE)
		))
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Snap to Grid")
	history.add_do(func() -> void:
		for i: int in objects.size():
			if is_instance_valid(objects[i]):
				objects[i].position = new_positions[i]
	)
	history.add_undo(func() -> void:
		for i: int in objects.size():
			if is_instance_valid(objects[i]):
				objects[i].position = old_positions[i]
	)
	history.commit_action()
	
	for i: int in objects.size():
		objects[i].position = new_positions[i]


func center_on_centroid() -> void:
	var objects: Array[LDObject] = _viewport.get_selected_objects()
	if objects.is_empty():
		return
	
	var centroid: Vector2 = Vector2.ZERO
	for obj: LDObject in objects:
		centroid += obj.position
	centroid = (centroid / objects.size()).snapped(Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE))
	
	var old_positions: Array[Vector2] = []
	for obj: LDObject in objects:
		old_positions.append(obj.position)
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Center on Centroid")
	history.add_do(func() -> void:
		for i: int in objects.size():
			if is_instance_valid(objects[i]):
				objects[i].position = centroid
	)
	history.add_undo(func() -> void:
		for i: int in objects.size():
			if is_instance_valid(objects[i]):
				objects[i].position = old_positions[i]
	)
	history.commit_action()
	
	for obj: LDObject in objects:
		obj.position = centroid


func distribute_centered() -> void:
	var objects: Array[LDObject] = _viewport.get_selected_objects()
	if objects.size() < 2:
		return
	
	objects.sort_custom(func(a: LDObject, b: LDObject) -> bool:
		return a.position.x < b.position.x
	)
	
	var total_width: float = 0.0
	for obj: LDObject in objects:
		total_width += obj.get_stamp_size().x
	
	var centroid_x: float = 0.0
	for obj: LDObject in objects:
		centroid_x += obj.position.x
	centroid_x /= objects.size()
	
	var start_x: float = centroid_x - total_width * 0.5
	var old_positions: Array[Vector2] = []
	var new_positions: Array[Vector2] = []
	for obj: LDObject in objects:
		old_positions.append(obj.position)
		new_positions.append(Vector2(snappedf(start_x, LDViewport.SNAPPING_SIZE), obj.position.y))
		start_x += obj.get_stamp_size().x
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Distribute Centered")
	history.add_do(func() -> void:
		for i: int in objects.size():
			if is_instance_valid(objects[i]):
				objects[i].position = new_positions[i]
	)
	history.add_undo(func() -> void:
		for i: int in objects.size():
			if is_instance_valid(objects[i]):
				objects[i].position = old_positions[i]
	)
	history.commit_action()
	
	for i: int in objects.size():
		objects[i].position = new_positions[i]


func flip_horizontal() -> void:
	var objects: Array[LDObject] = _viewport.get_selected_objects()
	if objects.is_empty():
		return
	
	var centroid_x: float = 0.0
	for obj: LDObject in objects:
		centroid_x += obj.position.x
	centroid_x /= objects.size()
	
	var old_positions: Array[Vector2] = []
	var old_flips: Array[bool] = []
	for obj: LDObject in objects:
		old_positions.append(obj.position)
		old_flips.append(obj.sprite_ref.flip_h if obj.sprite_ref else false)
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Flip Horizontal")
	history.add_do(func() -> void:
		for i: int in objects.size():
			if is_instance_valid(objects[i]):
				objects[i].position.x = snappedf(centroid_x * 2.0 - objects[i].position.x, LDViewport.SNAPPING_SIZE)
				if objects[i].sprite_ref:
					objects[i].sprite_ref.flip_h = not old_flips[i]
	)
	history.add_undo(func() -> void:
		for i: int in objects.size():
			if is_instance_valid(objects[i]):
				objects[i].position = old_positions[i]
				if objects[i].sprite_ref:
					objects[i].sprite_ref.flip_h = old_flips[i]
	)
	history.commit_action()
	
	for i: int in objects.size():
		objects[i].position.x = snappedf(centroid_x * 2.0 - objects[i].position.x, LDViewport.SNAPPING_SIZE)
		if objects[i].sprite_ref:
			objects[i].sprite_ref.flip_h = not old_flips[i]


func flip_vertical() -> void:
	var objects: Array[LDObject] = _viewport.get_selected_objects()
	if objects.is_empty():
		return
	
	var centroid_y: float = 0.0
	for obj: LDObject in objects:
		centroid_y += obj.position.y
	centroid_y /= objects.size()
	
	var old_positions: Array[Vector2] = []
	var old_flips: Array[bool] = []
	for obj: LDObject in objects:
		old_positions.append(obj.position)
		old_flips.append(obj.sprite_ref.flip_v if obj.sprite_ref else false)
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Flip Vertical")
	history.add_do(func() -> void:
		for i: int in objects.size():
			if is_instance_valid(objects[i]):
				objects[i].position.y = snappedf(centroid_y * 2.0 - objects[i].position.y, LDViewport.SNAPPING_SIZE)
				if objects[i].sprite_ref:
					objects[i].sprite_ref.flip_v = not old_flips[i]
	)
	history.add_undo(func() -> void:
		for i: int in objects.size():
			if is_instance_valid(objects[i]):
				objects[i].position = old_positions[i]
				if objects[i].sprite_ref:
					objects[i].sprite_ref.flip_v = old_flips[i]
	)
	history.commit_action()
	
	for i: int in objects.size():
		objects[i].position.y = snappedf(centroid_y * 2.0 - objects[i].position.y, LDViewport.SNAPPING_SIZE)
		if objects[i].sprite_ref:
			objects[i].sprite_ref.flip_v = not old_flips[i]
