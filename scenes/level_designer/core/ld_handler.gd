@abstract class_name LDHandler
extends Node

var editor: LD


func setup(host: LD) -> void:
	editor = host
	var components: Array[LDComponent] = get_components()
	for component: LDComponent in components:
		component.handler = self
	
	_setup()
	for component: LDComponent in components:
		component._setup()


func get_components() -> Array[LDComponent]:
	var components: Array[LDComponent] = []
	for child: Node in get_children():
		if child is LDComponent:
			components.append(child)
	
	return components


func get_component(type: Script) -> LDComponent:
	for component: LDComponent in get_components():
		if is_instance_of(component, type):
			return component
	
	return null


func has_component(type: Script) -> bool:
	return get_component(type) != null


func _setup() -> void:
	pass
