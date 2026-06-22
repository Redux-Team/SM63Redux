class_name LDEraseStroke

## A pending erase gesture. As the cursor passes over objects they are tinted red and remembered;
## commit() then deletes them (undoable), while cancel() restores them untouched. This lets the
## user release to confirm a deletion or press Escape to back out mid-drag. Shared by the dedicated
## eraser tool (left drag) and the brush (right drag).


const MARK_MODULATE: Color = Color(1.0, 0.35, 0.35, 0.65)


var _marked: Array[LDObject] = []
var _original_modulate: Array[Color] = []


func is_empty() -> bool:
	return _marked.is_empty()


func is_marked(obj: LDObject) -> bool:
	return obj in _marked


## Tints `obj` red and queues it for deletion, if it is erasable and not already marked.
func mark(obj: LDObject) -> void:
	if not is_instance_valid(obj) or obj in _marked:
		return
	if not LD.get_object_handler().can_delete(obj):
		return
	_marked.append(obj)
	_original_modulate.append(obj.modulate)
	obj.modulate = MARK_MODULATE


## Restores every marked object to its original tint and forgets them (deletes nothing).
func cancel() -> void:
	for i: int in _marked.size():
		var obj: LDObject = _marked[i]
		if is_instance_valid(obj):
			obj.modulate = _original_modulate[i]
	_clear()


## Restores tints (so undo brings objects back at their true colour) then deletes the marked set.
func commit() -> void:
	var to_delete: Array[LDObject] = []
	for i: int in _marked.size():
		var obj: LDObject = _marked[i]
		if is_instance_valid(obj):
			obj.modulate = _original_modulate[i]
			to_delete.append(obj)
	_clear()
	LD.get_object_handler().delete_objects(to_delete)


func _clear() -> void:
	_marked.clear()
	_original_modulate.clear()
