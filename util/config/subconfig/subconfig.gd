class_name Subconfig
extends Resource
# TODO (4.5) assign abstract

@export_group("Subconfig")
@export var id: StringName = &""


func get_settings(internal: bool = false) -> Dictionary[String, Variant]:
	var settings: Dictionary[String, Variant]
	
	for prop: Dictionary in get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			if not prop.name.begins_with("_") or internal:
				settings.set(prop.name, get(prop.name))
	
	return settings


func apply() -> void:
	pass
