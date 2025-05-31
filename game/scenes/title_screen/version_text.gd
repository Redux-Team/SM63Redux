@tool
extends ResizableLabel

func _ready() -> void:
	text = "v" + Singleton.VERSION
