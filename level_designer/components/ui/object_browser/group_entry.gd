class_name LDGroupItemEntry
extends Button


signal entry_selected(ref: LDGroupItemEntry)
signal entry_mouse_entered(ref: LDGroupItemEntry)
signal entry_mouse_exited(ref: LDGroupItemEntry)
signal entry_focus_entered(ref: LDGroupItemEntry)
signal entry_focus_exited(ref: LDGroupItemEntry)


@export var preview_rect: TextureRect
@export var group_label: Label

var group_ref: LDGroup


func setup(group: LDGroup) -> void:
	group_ref = group
	group_label.text = group.id
	preview_rect.texture = group.preview_texture


func _pressed() -> void:
	entry_selected.emit(self)


func _on_mouse_entered() -> void:
	entry_mouse_entered.emit(self)


func _on_mouse_exited() -> void:
	entry_mouse_exited.emit(self)


func _on_focus_entered() -> void:
	entry_focus_entered.emit(self)


func _on_focus_exited() -> void:
	entry_focus_exited.emit(self)
