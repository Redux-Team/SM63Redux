class_name LDStampEntry
extends Button


signal entry_selected(ref: LDStampEntry)
signal entry_mouse_entered(ref: LDStampEntry)
signal entry_mouse_exited(ref: LDStampEntry)
signal entry_focus_entered(ref: LDStampEntry)
signal entry_focus_exited(ref: LDStampEntry)


@export var preview_rect: TextureRect
@export var stamp_label: Label

var stamp_ref: LDStamp


func setup(stamp: LDStamp) -> void:
	stamp_ref = stamp
	stamp_label.text = stamp.id
	preview_rect.texture = stamp.preview_texture


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
