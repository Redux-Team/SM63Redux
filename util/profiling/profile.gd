class_name Profile

static var score_gradient: Gradient = Gradient.new()


static var profiles: Dictionary[String, Script] = {
	"instantiation": ProfileInstantiation,
	"shader": ProfileShader,
}

static var data: Dictionary[String, float] = {}


static func _static_init() -> void:
	score_gradient.offsets = PackedFloat32Array()
	score_gradient.add_point(0, Color.RED)
	score_gradient.add_point(0.5, Color.YELLOW)
	score_gradient.add_point(1.0, Color.GREEN)


static func run() -> void:
	print("\n=== Hardware ===")
	_print_component("CPU", OS.get_processor_name())
	_print_component("GPU", RenderingServer.get_video_adapter_name())
	_print_component("Available Memory", String.humanize_size(OS.get_memory_info()["available"]))
	_print_component("Total Memory", String.humanize_size(OS.get_memory_info()["physical"]))
	print("\n=== Profile ===")
	for profile_type: String in profiles.keys():
		var profile_script: Script = profiles[profile_type]
		data[profile_type] = await profile_script.call(&"run")
		_print_score(profile_type)


static func _print_score(type: String) -> void:
	var score: float = data[type]
	var score_color: Color = score_gradient.sample(inverse_lerp(-1.0, 1.0, score))
	print_rich("[b]%s[/b] - [color=#%s]%.2f" % [type, score_color.to_html(), score])


static func _print_component(component_name: String, value: String) -> void:
	print_rich("[b]%s[/b]: %s" % [component_name, value])
