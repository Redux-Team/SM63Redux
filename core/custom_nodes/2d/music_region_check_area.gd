class_name MusicRegionCheckArea
extends Area2D

## Player-side detector for music-region volumes. Mirrors WaterCheckArea: monitors the same physics
## layer as volumes (4) and filters by the `music_region` meta (whose value is the region id). Emits
## the currently-active region id on every enter/exit ("" when none), which drives
## MusicController.set_region so REGION subtracks crossfade in as the player walks into a region.


signal region_changed(region_id: String)


const REGION_META: StringName = &"music_region"


var _stack: Dictionary[Area2D, String]


func current_region() -> String:
	for id: String in _stack.values():
		return id
	return ""


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	set_deferred(&"monitorable", false)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _on_area_entered(area: Area2D) -> void:
	if area.has_meta(REGION_META) and area not in _stack:
		_stack.set(area, str(area.get_meta(REGION_META)))
		region_changed.emit(current_region())


func _on_area_exited(area: Area2D) -> void:
	if area.has_meta(REGION_META) and area in _stack:
		_stack.erase(area)
		region_changed.emit(current_region())
