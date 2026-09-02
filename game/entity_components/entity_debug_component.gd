class_name EntityDebugComponent
extends EntityComponent


@export var label: Label


func _ready() -> void:
	if not label:
		set_process(false)
		return
	
	Singleton.debug_mode_changed.connect(_on_debug_mode_changed)
	_on_debug_mode_changed()


func _process(_delta: float) -> void:
	if label.visible:
		label.text = entity.get_debug_text()


func _on_debug_mode_changed() -> void:
	label.visible = enabled and Singleton.is_verbose()
