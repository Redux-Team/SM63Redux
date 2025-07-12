extends Label

func _ready() -> void:
	text = "v" + Singleton.VERSION
