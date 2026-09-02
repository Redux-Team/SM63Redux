class_name LevelObject
extends Node2D


@export var spawn_offset: Vector2
@export var body: CollisionObject2D
@export var terrain_type: String
@export var palette_objects: Array[CanvasItem]
## Objects off screen are suspended by [LevelCuller]. Turn this off for anything that must keep
## running out of view, such as a platform carrying the player or a timed hazard.
@export var cull_when_offscreen: bool = true

signal initialized

var data: Dictionary
var properties: Dictionary = {}
var source_object_id: String = ""

## Greyed out and inert in the level designer, stopped here. One field, meaning the same thing on
## both sides because each implements it in its own terms.
var disabled: bool = false:
	set(value):
		disabled = value
		set_process(not value)
		set_physics_process(not value)
		set_process_internal(not value)

## The object's own field definitions, taken from the database on init so the values a level saved
## can be coerced and applied through the very definitions the designer edited them with.
var _schema: Array[LDProperty] = []


func init_from_data(obj_data: Dictionary) -> void:
	data = obj_data
	source_object_id = obj_data.get("object_id", "")
	properties = obj_data.get("properties", {})
	_pre_init()
	_handle_properties()
	
	position += spawn_offset
	
	if body:
		body.set_meta(&"terrain", terrain_type)
	
	initialized.emit()
	_on_init()


func get_property(key: StringName, default: Variant = null) -> Variant:
	return properties.get(key, default)


func set_property(key: StringName, value: Variant) -> void:
	properties.set(key, value)
	_on_property_changed(key, value)


## Main property method to be overridden, if necessary. This will go property by property. Call super()
## to let the superclass handle the property (if applicable).
##
## A field that declares what it does is applied through its own definition, in the same terms the
## level designer applies it. Anything else is set on the node by name, which is how a hand-authored
## scene's exported fields get filled in.
func _handle_property(property_name: String, property_value: Variant) -> void:
	var prop: LDProperty = _find_property(property_name)
	if prop and prop.apply_mode != LDProperty.Apply.NONE:
		prop.apply(self, property_value)
		return
	
	set(property_name, _as_node_type(property_name, property_value))


## A level writes vectors and colors as arrays, and a field the object no longer declares has no
## definition left to coerce one back with. Handing the node an [Array] where it holds a [Vector2]
## resolves to zero rather than being ignored - which scales an object down to nothing instead of
## leaving it alone - so the value the node already holds says what the type should be.
func _as_node_type(property_name: String, value: Variant) -> Variant:
	if value is not Array:
		return value
	
	match typeof(get(property_name)):
		TYPE_VECTOR2:
			return Packer.array_to_vec2(value)
		TYPE_COLOR:
			return Packer.array_to_color(value)
	
	return value


## Overrides the full property logic of the object.
##
## Every field the object declares is run, not only the ones this level happened to save, so a field
## added to an object after a level was written arrives with its default instead of being skipped.
func _handle_properties() -> void:
	var game_object: GameObject = GameDB.get_object(source_object_id)
	_schema = game_object.get_properties() if game_object else []
	
	var declared: Dictionary[StringName, bool] = {}
	for prop: LDProperty in _schema:
		declared.set(prop.key, true)
		var value: Variant = prop.coerce(properties.get(prop.key, prop.default_value))
		properties.set(prop.key, value)
		_handle_property(prop.key, value)
	
	# Anything the level saved that the object no longer declares still reaches the node, so pulling
	# a field out of the database doesn't silently drop data a script is still reading.
	for saved_key: Variant in properties.keys():
		if not declared.has(StringName(saved_key)):
			_handle_property(str(saved_key), properties.get(saved_key))


## Uniform-driven fields (a palette index, say) reach the object through this, named to match the
## editor object's own setter so [constant LDProperty.Apply.SHADER_PARAM] works on both sides.
func set_shader_parameter(parameter: StringName, value: Variant) -> void:
	for item: CanvasItem in palette_objects:
		if item and item.material is ShaderMaterial:
			(item.material as ShaderMaterial).set_shader_parameter(parameter, value)


## Shape [CollisionTrait] falls back to when an object asks for collision without describing one.
func get_default_collision_shape() -> Shape2D:
	return null


## Called before properties are set
func _pre_init() -> void:
	if not Singleton.get_multiplayer_handler().is_server():
		set_process(false)


## Called after properties are set
func _on_init() -> void:
	pass


func _on_property_changed(_key: StringName, _value: Variant) -> void:
	pass


func _find_property(property_name: String) -> LDProperty:
	for prop: LDProperty in _schema:
		if prop.key == property_name:
			return prop
	return null
