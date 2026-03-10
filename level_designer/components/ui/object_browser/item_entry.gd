class_name LDObjectItemEntry
extends Button

signal entry_mouse_entered(obj: GameObject)
signal entry_mouse_exited(obj: GameObject)

@export var obj_ref: GameObject

@export_group("Internal")
@export var preview_texture_rect: TextureRect
@export var item_id: Label


func _ready() -> void:
	item_id.text = obj_ref.id
	if obj_ref.ld_preview_texture:
		preview_texture_rect.texture = obj_ref.ld_preview_texture
		item_id.hide()
	else:
		item_id.show()


func _on_mouse_entered() -> void:
	entry_mouse_entered.emit(obj_ref)


func _on_mouse_exited() -> void:
	entry_mouse_exited.emit(obj_ref)
