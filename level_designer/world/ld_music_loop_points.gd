class_name LDMusicLoopPoints
extends Resource


@export var entries: Array[Dictionary] = []


func loop_start_for(id: String) -> float:
	if id.is_empty():
		return 0.0
	for entry: Dictionary in entries:
		if str(entry.get("id", "")) == id:
			var value: float = float(entry.get("loop_start", -1.0))
			return value if value > 0.0 else 0.0
	return 0.0
