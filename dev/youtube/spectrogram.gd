extends Control

#@export var analysis_bus_layout: AudioBusLayout
@export var bus: StringName
var bus_id: int
var inst: AudioEffectSpectrumAnalyzerInstance

@export_group("Attributes")
@export var steps: int = 50
@export var min_freq: float = 0
@export var max_freq: float = 20000
@export var min_db: float = -80
@export var max_db: float = 250

@export_group("Visual")
@export var gradient: Gradient
@export_range(0, 1) var bar_gap_ratio: float = 0.6

# Get the audio effect instance
func _ready() -> void:
	#AudioServer.set_bus_layout(analysis_bus_layout)
	bus_id = AudioServer.get_bus_index(bus)
	inst = AudioServer.get_bus_effect_instance(bus_id, 0)

# Redraw every frame.
func _process(_delta: float) -> void:
	queue_redraw()

# Draw the spectrogram bars.
func _draw() -> void:
	# Current frequency and bar position, used and modified in loop.
	var cur_freq : float = min_freq
	var cur_pos : float = 0
	
	# Bar width.
	var bar_width : float = size.x / steps
	
	# Frequency step size.
	var step_size : float = (max_freq - min_freq) / steps
	
	# Draw each bar.
	for i: int in steps:
		# dB of the current frequency.
		var bar_db : float = linear_to_db(
				inst.get_magnitude_for_frequency_range(cur_freq, cur_freq + step_size)
					.length()
		)
		#print(bar_db)
		
		# Convert dB into bar height:
		var bar_height : float = remap(bar_db,
				min_db, max_db,
				0, size.y
		)
		
		draw_rect(
			Rect2(cur_pos, 0, 
					bar_width * bar_gap_ratio,
					bar_height
			), 
			gradient.sample(float(i) / steps)
		)
		cur_freq += step_size
		cur_pos += bar_width
