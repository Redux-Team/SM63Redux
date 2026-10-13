@abstract class_name LDTool
extends LDComponent

@export var button: BaseButton
@export var action: StringName
@export var shape_kinds: Array[ObjectShape.Kind]
@export var cursor: Control.CursorShape = Control.CURSOR_ARROW


@abstract func _tool_input(event: InputEvent, world_position: Vector2) -> bool


func is_active() -> bool:
	return editor.tool_handler.active_tool == self


func _activate() -> void:
	pass


func _deactivate() -> void:
	pass


func _cancel() -> void:
	pass


func _draw_overlay(_overlay: LDOverlay) -> void:
	pass
