class_name EntityDebugComponent
extends EntityComponent


@export var label: Label


func _ready() -> void:
	if not label:
		set_process(false)
		return
	
	label.visible = false


func _process(_delta: float) -> void:
	if label.visible:
		label.text = entity.get_debug_text()


func _input(event: InputEvent) -> void:
	if label and event.is_action_pressed("toggle_debug"):
		label.visible = enabled and not label.visible
