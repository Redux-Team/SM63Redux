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
	
	LD.get_history_handler().push("Align Horizontal",
		func() -> void:
			for i: int in objects.size():
				if is_instance_valid(objects.get(i)):
					objects.get(i).position.y = avg_y,
		func() -> void:
			for i: int in objects.size():
				if is_instance_valid(objects.get(i)):
					objects.get(i).position = old_positions.get(i)
	)


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
		old_positions.append(objects.get(i).position)
		new_positions.append(Vector2(snappedf(start_x + i * stamp_size, LDViewport.SNAPPING_SIZE), avg_y))
	
	LD.get_history_handler().push("Align Horizontal Spaced",
		func() -> void:
			for i: int in objects.size():
				if is_instance_valid(objects.get(i)):
					objects.get(i).position = new_positions.get(i),
		func() -> void:
			for i: int in objects.size():
				if is_instance_valid(objects.get(i)):
					objects.get(i).position = old_positions.get(i)
	)


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
	
	LD.get_history_handler().push("Align Vertical",
		func() -> void:
			for i: int in objects.size():
				if is_instance_valid(objects.get(i)):
					objects.get(i).position.x = avg_x,
		func() -> void:
			for i: int in objects.size():
				if is_instance_valid(objects.get(i)):
					objects.get(i).position = old_positions.get(i)
	)


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
		old_positions.append(objects.get(i).position)
		new_positions.append(Vector2(avg_x, snappedf(start_y + i * stamp_size, LDViewport.SNAPPING_SIZE)))
	
	LD.get_history_handler().push("Align Vertical Spaced",
		func() -> void:
			for i: int in objects.size():
				if is_instance_valid(objects.get(i)):
					objects.get(i).position = new_positions.get(i),
		func() -> void:
			for i: int in objects.size():
				if is_instance_valid(objects.get(i)):
					objects.get(i).position = old_positions.get(i)
	)


func duplicate_selection() -> void:
	var objects: Array[LDObject] = _viewport.get_selected_objects()
	if objects.is_empty():
		return
	
	var area: LDArea = LDLevel.get_active_area()
	var duplicates: Array[LDObject] = []
	for obj: LDObject in objects:
		var dupe: LDObject = obj.duplicate() as LDObject
		area.add_object(dupe, Vector2i(obj.position + Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE)))
		dupe.place()
		duplicates.append(dupe)
	
	LD.get_history_handler().push("Duplicate Objects",
		func() -> void:
			for dupe: LDObject in duplicates:
				if is_instance_valid(dupe):
					dupe.show(),
		func() -> void:
			for dupe: LDObject in duplicates:
				if is_instance_valid(dupe):
					dupe.hide()
	)
	
	_viewport.set_selected_objects(duplicates)


func delete_selection() -> void:
	var objects: Array[LDObject] = _viewport.get_selected_objects()
	if objects.is_empty():
		return
	
	var parents: Array[Node] = []
	for obj: LDObject in objects:
		parents.append(obj.get_parent())
	
	_viewport.clear_selection()
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.push("Delete Objects",
		func() -> void:
			for obj: LDObject in objects:
				if is_instance_valid(obj) and obj.get_parent():
					obj.get_parent().remove_child(obj),
		func() -> void:
			for i: int in objects.size():
				if is_instance_valid(objects.get(i)) and is_instance_valid(parents.get(i)):
					parents.get(i).add_child(objects.get(i))
	)
	history.track_detached(objects)


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
	
	LD.get_history_handler().push("Snap to Grid",
		func() -> void:
			for i: int in objects.size():
				if is_instance_valid(objects.get(i)):
					objects.get(i).position = new_positions.get(i),
		func() -> void:
			for i: int in objects.size():
				if is_instance_valid(objects.get(i)):
					objects.get(i).position = old_positions.get(i)
	)


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
	
	LD.get_history_handler().push("Center on Centroid",
		func() -> void:
			for i: int in objects.size():
				if is_instance_valid(objects.get(i)):
					objects.get(i).position = centroid,
		func() -> void:
			for i: int in objects.size():
				if is_instance_valid(objects.get(i)):
					objects.get(i).position = old_positions.get(i)
	)


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
	
	LD.get_history_handler().push("Distribute Centered",
		func() -> void:
			for i: int in objects.size():
				if is_instance_valid(objects.get(i)):
					objects.get(i).position = new_positions.get(i),
		func() -> void:
			for i: int in objects.size():
				if is_instance_valid(objects.get(i)):
					objects.get(i).position = old_positions.get(i)
	)


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
	
	LD.get_history_handler().push("Flip Horizontal",
		func() -> void:
			for i: int in objects.size():
				if is_instance_valid(objects.get(i)):
					objects.get(i).position.x = snappedf(centroid_x * 2.0 - objects.get(i).position.x, LDViewport.SNAPPING_SIZE)
					if objects.get(i).sprite_ref:
						objects.get(i).sprite_ref.flip_h = not old_flips.get(i),
		func() -> void:
			for i: int in objects.size():
				if is_instance_valid(objects.get(i)):
					objects.get(i).position = old_positions.get(i)
					if objects.get(i).sprite_ref:
						objects.get(i).sprite_ref.flip_h = old_flips.get(i)
	)


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
	
	LD.get_history_handler().push("Flip Vertical",
		func() -> void:
			for i: int in objects.size():
				if is_instance_valid(objects.get(i)):
					objects.get(i).position.y = snappedf(centroid_y * 2.0 - objects.get(i).position.y, LDViewport.SNAPPING_SIZE)
					if objects.get(i).sprite_ref:
						objects.get(i).sprite_ref.flip_v = not old_flips.get(i),
		func() -> void:
			for i: int in objects.size():
				if is_instance_valid(objects.get(i)):
					objects.get(i).position = old_positions.get(i)
					if objects.get(i).sprite_ref:
						objects.get(i).sprite_ref.flip_v = old_flips.get(i)
	)
