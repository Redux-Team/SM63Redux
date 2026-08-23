extends Level
# Loads a (spectrogram) scene into the level, as a child of a layer.
# Switch out the script in the level.tscn scene to make this work.

@export var scene: PackedScene
@export var instantiate_at_layer_index: int

# Area loading method is overridden.
func load_from_dict(data: Dictionary, scenario_index: int = 0) -> Error:
	var error_code: Error = super(data, scenario_index)
	if error_code == ERR_INVALID_DATA: return error_code
	
	var normalized: Dictionary = _normalize(data)
	var areas_list: Array = normalized.get("areas", [])
	# In all areas...
	for area_variant: Variant in areas_list:
		var area_data: Dictionary = area_variant
		var current_area: LevelArea = _get_or_create_area(str(area_data.get("name", "default")))
		# Add the scene as a child of the area
		var scene_root: Node = scene.instantiate()
		current_area.add_child(scene_root)
		current_area.move_child(scene_root, instantiate_at_layer_index)
	
	return error_code
