class_name EntityDebugComponent
extends EntityComponent


@export var label: Label


func _process(_delta: float) -> void:
	if enabled and label:
		label.text = entity.get_debug_text()
