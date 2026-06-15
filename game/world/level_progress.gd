class_name LevelProgress
extends RefCounted

## Per-run record of what the player has collected in a level. Generic by design: every collectible
## is tracked under a category (e.g. [constant CATEGORY_SHINE]) by a unique id, so new collectible
## types can be added without new bookkeeping. Coin counts still live on [Level] for now; they can
## migrate here later.

const CATEGORY_SHINE: StringName = &"shine"
const CATEGORY_STAR_COIN: StringName = &"star_coin"

# category (String) -> { id (String): true }
var _collected: Dictionary[String, Dictionary] = {}


## Marks [param id] collected under [param category]. Returns true if it was newly collected, or
## false if it had already been recorded.
func collect(category: StringName, id: Variant) -> bool:
	var key: String = str(category)
	var ids: Dictionary = _collected.get(key, {})
	var id_key: String = str(id)
	if ids.has(id_key):
		return false
	ids[id_key] = true
	_collected[key] = ids
	return true


## Whether [param id] has been collected under [param category].
func has_collected(category: StringName, id: Variant) -> bool:
	return (_collected.get(str(category), {}) as Dictionary).has(str(id))


## How many distinct items have been collected under [param category].
func count(category: StringName) -> int:
	return (_collected.get(str(category), {}) as Dictionary).size()


## The collected ids (as strings) under [param category].
func get_ids(category: StringName) -> Array:
	return (_collected.get(str(category), {}) as Dictionary).keys()


func clear() -> void:
	_collected.clear()


## Flattens to a JSON-friendly dictionary: { category: [ids] }.
func serialize() -> Dictionary:
	var out: Dictionary = {}
	for category: String in _collected:
		out[category] = (_collected[category] as Dictionary).keys()
	return out


static func deserialize(data: Dictionary) -> LevelProgress:
	var progress: LevelProgress = LevelProgress.new()
	for category: Variant in data:
		var ids: Variant = data[category]
		if not ids is Array:
			continue
		for id: Variant in ids as Array:
			progress.collect(StringName(str(category)), id)
	return progress
