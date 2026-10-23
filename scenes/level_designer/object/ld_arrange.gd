class_name LDArrange
extends LDComponent

@export var front_button: BaseButton
@export var back_button: BaseButton


func _setup() -> void:
	var objects: LDObjectHandler = editor.object_handler
	LD.bind_button(
			front_button,
			func() -> void:
				objects.reorder_objects(objects.selection.get_objects(), true)
	)
	LD.bind_button(
			back_button,
			func() -> void:
				objects.reorder_objects(objects.selection.get_objects(), false)
	)
	objects.selection.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var empty: bool = editor.object_handler.selection.is_empty()
	LD.set_disabled(front_button, empty)
	LD.set_disabled(back_button, empty)
