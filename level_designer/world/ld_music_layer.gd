class_name LDMusicLayer
extends Resource


enum Trigger {
	ALWAYS,
	UNDERWATER,
}


@export var track_id: String = ""
@export var trigger: Trigger = Trigger.ALWAYS
@export var volume_db: float = 0.0
@export var fade_time: float = 1.0


func serialize() -> Dictionary:
	return {
		"track_id": track_id,
		"trigger": int(trigger),
		"volume_db": volume_db,
		"fade_time": fade_time,
	}


static func deserialize(data: Dictionary) -> LDMusicLayer:
	var layer: LDMusicLayer = LDMusicLayer.new()
	layer.track_id = str(data.get("track_id", ""))
	layer.trigger = int(data.get("trigger", Trigger.ALWAYS))
	layer.volume_db = float(data.get("volume_db", 0.0))
	layer.fade_time = float(data.get("fade_time", 1.0))
	return layer
