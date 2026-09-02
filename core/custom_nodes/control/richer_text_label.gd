@tool
class_name RicherTextLabel
extends RichTextLabel


func _init() -> void:
	if not custom_effects:
		custom_effects = [
			HintTextEffect.new()
		]
