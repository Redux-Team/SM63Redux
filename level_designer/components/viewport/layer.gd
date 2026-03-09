class_name LDLayer
extends Node2D

@export var layer_id: String = "a0"
@export var absolute_index: int = 0
@export var relative_index: int = 0
@export var decoration_layer: bool = false
@export var parallax_scale: Vector2 = Vector2.ONE
@export var modulate_color: Color = Color.WHITE


func _ready() -> void:
	modulate = modulate_color
	if not decoration_layer:
		return
	set_process(false)
	set_physics_process(false)


func _process(_delta: float) -> void:
	if not decoration_layer or parallax_scale == Vector2.ONE:
		return
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam:
		position = cam.global_position * (Vector2.ONE - parallax_scale)

@warning_ignore("shadowed_variable")
static func parse_id(layer_id: String) -> Dictionary:
	var result: Dictionary = {"absolute_index": 0, "relative_index": 0}
	var regex: RegEx = RegEx.new()
	regex.compile("(?:a(-?\\d+))?(?:r(-?\\d+))?")
	var match: RegExMatch = regex.search(layer_id)
	if not match:
		return result
	if match.get_string(1) != "":
		result.absolute_index = int(match.get_string(1))
	if match.get_string(2) != "":
		result.relative_index = int(match.get_string(2))
	return result

@warning_ignore("shadowed_variable")
static func normalize_id(layer_id: String) -> String:
	var parsed: Dictionary = parse_id(layer_id)
	return "a%dr%d" % [parsed.absolute_index, parsed.relative_index]
