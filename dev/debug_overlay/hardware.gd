extends RichTextLabel


const TEXT: String = """[b]hardware[/b]
cpu: %s
gpu: %s
"""


func _process(_delta: float) -> void:
	text = TEXT % [
		OS.get_processor_name(),
		RenderingServer.get_video_adapter_name(),
	]
