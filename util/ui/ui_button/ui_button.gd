@tool
class_name UIButton
extends Button

var label: Label


func _init() -> void:
	for child: Node in get_children(true):
		child.queue_free()
	label = Label.new()
	add_child(label, false, Node.INTERNAL_MODE_BACK)
	
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.call_deferred(&"set_anchors_and_offsets_preset", Control.PRESET_CENTER)
	GDSS.enable_gdss(self)


func _set(property: StringName, value: Variant) -> bool:
	if property == &"text":
		label.text = value
		label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	return false
