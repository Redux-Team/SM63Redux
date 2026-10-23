extends RichTextLabel

const TEXT: String = """[b]profile[/b]
fps: %s
process: %.4fms
physics: %.4fms
draw calls: %d

memory: %s - %s
vram: %s

objects: %d
nodes: %d
orphans: %d
"""


func _process(_delta: float) -> void:
	@warning_ignore("narrowing_conversion")
	text = TEXT % [
		Performance.get_monitor(Performance.TIME_FPS),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		
		String.humanize_size(Performance.get_monitor(Performance.MEMORY_STATIC)),
		String.humanize_size(OS.get_memory_info().available),
		String.humanize_size(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
	]
