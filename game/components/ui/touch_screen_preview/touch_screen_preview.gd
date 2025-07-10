class_name TouchScreenPreview
extends Control

@export var buttons: Array[DraggableItem]


func apply_scale(new_scale: float) -> void:
	for button: DraggableItem in buttons:
		button.scale = Vector2(new_scale, new_scale)


func apply_opacity(amount: float) -> void:
	for button: DraggableItem in buttons:
		button.self_modulate.a = amount / 100.0
