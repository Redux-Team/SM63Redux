class_name LDObjectItemEntry
extends Button

signal entry_mouse_entered(ref: LDObjectItemEntry)
signal entry_mouse_exited(ref: LDObjectItemEntry)
signal entry_focus_entered(ref: LDObjectItemEntry)
signal entry_focus_exited(ref: LDObjectItemEntry)
signal entry_selected(ref: LDObjectItemEntry)

@export var obj_ref: GameObject

@export_group("Internal")
@export var preview_texture_rect: TextureRect
@export var item_id: Label


func _ready() -> void:
	var has_texture: bool = obj_ref.ld_entry_texture != null
	var show_caption: bool = not has_texture or not Device.is_desktop()
	item_id.text = obj_ref.get_object_name()
	preview_texture_rect.texture = obj_ref.ld_entry_texture
	preview_texture_rect.visible = has_texture
	item_id.visible = show_caption
	if not has_texture:
		item_id.size_flags_vertical = Control.SIZE_EXPAND_FILL


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
