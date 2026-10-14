@abstract class_name LDTool
extends LDComponent

@export var button: BaseButton
@export var preferred: bool = false
@export var group_button: BaseButton
@export var action: StringName
@export var shape_kinds: Array[ObjectShape.Kind]
@export var edit_kinds: Array[ObjectShape.Kind]
@export var cursor: Control.CursorShape = Control.CURSOR_ARROW

var _view: Transform2D


@abstract func _tool_input(event: InputEvent, world_position: Vector2) -> bool


func is_active() -> bool:
	return editor.tool_handler.active_tool == self


func _process(_delta: float) -> void:
	if handler == null or not is_active() or editor.level_handler.active_layer == null:
		return
	
	var view: Transform2D = editor.level_handler.active_layer.get_objects_root().get_global_transform()
	if view != _view:
		_view = view
		_view_changed()


func _view_changed() -> void:
	pass


func _activate() -> void:
	pass


func _deactivate() -> void:
	pass


func _cancel() -> void:
	pass


func _draw_overlay(_overlay: LDOverlay) -> void:
	pass
