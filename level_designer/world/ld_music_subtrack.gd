class_name LDMusicSubtrack
extends Resource


enum Trigger {
	ALWAYS,
	UNDERWATER,
	REGION,
}


@export var track_id: String = ""
@export var trigger: Trigger = Trigger.ALWAYS
@export var region_id: String = ""
@export var volume_db: float = 0.0
@export var fade_time: float = 1.0
@export var muffled: bool = false


func serialize() -> Dictionary:
	return {
		"track_id": track_id,
		"trigger": int(trigger),
		"region_id": region_id,
		"volume_db": volume_db,
		"fade_time": fade_time,
		"muffled": muffled,
	}


static func deserialize(data: Dictionary) -> LDMusicSubtrack:
	var subtrack: LDMusicSubtrack = LDMusicSubtrack.new()
	subtrack.track_id = str(data.get("track_id", ""))
	subtrack.trigger = int(data.get("trigger", Trigger.ALWAYS))
	subtrack.region_id = str(data.get("region_id", ""))
	subtrack.volume_db = float(data.get("volume_db", 0.0))
	subtrack.fade_time = float(data.get("fade_time", 1.0))
	subtrack.muffled = bool(data.get("muffled", false))
	return subtrack
