class_name LDSelectionShortcutHandler
extends Node


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
		if shift:
			align_horizontal_spaced()
		else:
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
	avg_y /= objects.size()
	
	for obj: LDObject in objects:
		obj.position.y = snappedf(avg_y, LDViewport.SNAPPING_SIZE)


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
	avg_y /= objects.size()
	avg_y = snappedf(avg_y, LDViewport.SNAPPING_SIZE)
	
	var start_x: float = objects.front().position.x
	var stamp_size: float = objects.front().get_stamp_size().x
	
	for i: int in objects.size():
		objects[i].position = Vector2(
			snappedf(start_x + i * stamp_size, LDViewport.SNAPPING_SIZE),
			avg_y
		)


func align_vertical() -> void:
	var objects: Array[LDObject] = _viewport.get_selected_objects()
	if objects.is_empty():
		return
	
	var avg_x: float = 0.0
	for obj: LDObject in objects:
		avg_x += obj.position.x
	avg_x /= objects.size()
	
	for obj: LDObject in objects:
		obj.position.x = snappedf(avg_x, LDViewport.SNAPPING_SIZE)


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
	avg_x /= objects.size()
	avg_x = snappedf(avg_x, LDViewport.SNAPPING_SIZE)
	
	var start_y: float = objects.front().position.y
	var stamp_size: float = objects.front().get_stamp_size().y
	
	for i: int in objects.size():
		objects[i].position = Vector2(
			avg_x,
			snappedf(start_y + i * stamp_size, LDViewport.SNAPPING_SIZE)
		)


func duplicate_selection() -> void:
	var objects: Array[LDObject] = _viewport.get_selected_objects()
	if objects.is_empty():
		return
	
	var duplicates: Array[LDObject] = []
	for obj: LDObject in objects:
		var dupe: LDObject = obj.duplicate() as LDObject
		_viewport.add_object(dupe, Vector2i(obj.position + Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE)))
		duplicates.append(dupe)
	
	_viewport.set_selected_objects(duplicates)


func delete_selection() -> void:
	var objects: Array[LDObject] = _viewport.get_selected_objects()
	if objects.is_empty():
		return
	
	_viewport.clear_selection()
	for obj: LDObject in objects:
		obj.queue_free()


func snap_to_grid() -> void:
	var objects: Array[LDObject] = _viewport.get_selected_objects()
	for obj: LDObject in objects:
		obj.position = Vector2(
			snappedf(obj.position.x, LDViewport.SNAPPING_SIZE),
			snappedf(obj.position.y, LDViewport.SNAPPING_SIZE)
		)


func center_on_centroid() -> void:
	var objects: Array[LDObject] = _viewport.get_selected_objects()
	if objects.is_empty():
		return
	
	var centroid: Vector2 = Vector2.ZERO
	for obj: LDObject in objects:
		centroid += obj.position
	centroid /= objects.size()
	centroid = centroid.snapped(Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE))
	
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
	for obj: LDObject in objects:
		obj.position.x = snappedf(start_x, LDViewport.SNAPPING_SIZE)
		start_x += obj.get_stamp_size().x


func flip_horizontal() -> void:
	var objects: Array[LDObject] = _viewport.get_selected_objects()
	if objects.is_empty():
		return
	
	var centroid_x: float = 0.0
	for obj: LDObject in objects:
		centroid_x += obj.position.x
	centroid_x /= objects.size()
	
	for obj: LDObject in objects:
		obj.position.x = snappedf(centroid_x * 2.0 - obj.position.x, LDViewport.SNAPPING_SIZE)
		if obj.sprite_ref:
			obj.sprite_ref.flip_h = not obj.sprite_ref.flip_h


func flip_vertical() -> void:
	var objects: Array[LDObject] = _viewport.get_selected_objects()
	if objects.is_empty():
		return
	
	var centroid_y: float = 0.0
	for obj: LDObject in objects:
		centroid_y += obj.position.y
	centroid_y /= objects.size()
	
	for obj: LDObject in objects:
		obj.position.y = snappedf(centroid_y * 2.0 - obj.position.y, LDViewport.SNAPPING_SIZE)
		if obj.sprite_ref:
			obj.sprite_ref.flip_v = not obj.sprite_ref.flip_v
