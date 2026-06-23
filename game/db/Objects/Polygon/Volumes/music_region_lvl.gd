@tool
class_name LevelObjectMusicRegion
extends LevelObjectPolygon

## An invisible polygon trigger volume that tags its Area2D with the designer-set `music_region` id.
## The player's MusicRegionCheckArea reads that id and drives MusicController.set_region, so REGION
## subtracks of the level's music crossfade in while the player is inside the volume.


@export var region_area: Area2D


var region_id: String = ""


func _handle_property(property_name: String, property_value: Variant) -> void:
	if property_name == "music_region":
		region_id = str(property_value)
		_apply_region_meta()
	else:
		super._handle_property(property_name, property_value)


func _on_init() -> void:
	super._on_init()
	_apply_region_meta()


func _apply_region_meta() -> void:
	if region_area:
		region_area.set_meta(&"music_region", region_id)
