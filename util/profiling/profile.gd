class_name Profile

static var SCORE_GRADIENT: Gradient = Gradient.new()


static var PROFILES: Dictionary[String, Script] = {
	"instantiation": ProfileInstantiation,
	"shader": ProfileShader,
}

static var DATA: Dictionary[String, float] = {}


static func _static_init() -> void:
	SCORE_GRADIENT.offsets = PackedFloat32Array()
	SCORE_GRADIENT.add_point(0, Color.RED)
	SCORE_GRADIENT.add_point(0.5, Color.YELLOW)
	SCORE_GRADIENT.add_point(1.0, Color.GREEN)


static func run() -> void:
	print("\n=== Hardware ===")
	_print_component("CPU", OS.get_processor_name())
	_print_component("GPU", RenderingServer.get_video_adapter_name())
	_print_component("Available Memory", String.humanize_size(OS.get_memory_info().get("available")))
	_print_component("Total Memory", String.humanize_size(OS.get_memory_info().get("physical")))
	print("\n=== Profile ===")
	for profile_type: String in PROFILES.keys():
		var profile_script: Script = PROFILES.get(profile_type)
		DATA.set(profile_type, await profile_script.call(&"run"))
		_print_score(profile_type)


static func _print_score(type: String) -> void:
	var score: float = DATA.get(type)
	var score_color: Color = SCORE_GRADIENT.sample(inverse_lerp(-1.0, 1.0, score))
	print_rich("[b]%s[/b] - [color=#%s]%.2f" % [type, score_color.to_html(), score])


static func _print_component(component_name: String, value: String) -> void:
	print_rich("[b]%s[/b]: %s" % [component_name, value])
