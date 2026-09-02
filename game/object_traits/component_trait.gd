@tool
class_name ComponentTrait
extends ObjectTrait

## Hangs one of the game's [EntityComponent]s on an object from the database, so behaviour an
## existing component already implements - bouncing, gravity, health - can be added to an object
## without a scene being written to hold it.
##
## [member overrides] sets the component's own exported fields by name, which is what keeps two
## objects sharing a component but not its tuning from needing two components.


@export var component: Script
@export var overrides: Dictionary[StringName, Variant]


func build_game(obj: Node) -> void:
	if not component:
		return
	
	var instance: Node = component.new() as Node
	if not instance:
		push_warning("ComponentTrait: %s is not a Node script." % component.resource_path)
		return
	
	instance.name = component.get_global_name() if not component.get_global_name().is_empty() else "Component"
	for key: StringName in overrides:
		instance.set(key, overrides.get(key))
	
	var entity: Entity = obj as Entity
	var parent: Node = entity.components_root if entity and entity.components_root else obj
	parent.add_child(instance)
	
	if entity and instance is EntityComponent:
		(instance as EntityComponent).entity = entity
