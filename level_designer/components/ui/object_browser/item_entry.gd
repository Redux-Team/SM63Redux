class_name LDObjectItemEntry
extends Button

signal entry_mouse_entered(ref: LDObjectItemEntry)
signal entry_mouse_exited(ref: LDObjectItemEntry)
signal entry_selected(ref: LDObjectItemEntry)

@export var obj_ref: GameObject

@export_group("Internal")
@export var preview_texture_rect: TextureRect
@export var item_id: Label


func _ready() -> void:
	item_id.text = obj_ref.id
	if obj_ref.ld_entry_texture:
		preview_texture_rect.texture = obj_ref.ld_entry_texture
		item_id.hide()
	else:
		item_id.show()


func _pressed() -> void:
	entry_selected.emit(self)


func _on_mouse_entered() -> void:
	entry_mouse_entered.emit(self)


func _on_mouse_exited() -> void:
	entry_mouse_exited.emit(self)
