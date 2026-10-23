extends RichTextLabel


const TEXT: String = """[b]input[/b]
last event: %s
device id: %s
"""


func _input(event: InputEvent) -> void:
	if event is not InputEventMouseMotion:
		text = TEXT % [
			event.as_text(),
			event.device,
		]
