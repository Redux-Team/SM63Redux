class_name Packer
extends Resource
## Helper class to easily pack/unpack data.


static func merge_deep(base: Dictionary, override: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	for key in override.keys():
		if result.has(key) and typeof(result[key]) == TYPE_DICTIONARY and typeof(override[key]) == TYPE_DICTIONARY:
			result[key] = merge_deep(result[key], override[key])
		else:
			result[key] = override[key]
	return result
