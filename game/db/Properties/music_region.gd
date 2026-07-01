@tool
class_name LDPropertyMusicRegion
extends LDProperty


func _init() -> void:
	key = &"music_region"
	label = "Music Region"
	type = LDProperty.Type.STRING
	default_value = ""
	exclusive = false
