class_name LDObjectBrowser
extends Control

signal category_changed(category_name: String)
signal hide_request

@export var groups_v_box: VBoxContainer
@export var entities_button: Button
const OBJECT_GROUP_SCENE = preload("uid://d11ohrgxcihxx")


func _ready() -> void:
	populate_list()


func populate_list(category: GameObject.ObjectCategory = GameObject.ObjectCategory.ALL) -> void:
	#aka if none are selected
	if entities_button.button_group.get_pressed_button() == null and category != GameObject.ObjectCategory.ALL:
		SFX.play(SFX.UI_BACK)
		populate_list()
		return
	
	for n: Node in groups_v_box.get_children(): n.queue_free()
	
	var objects: Array[GameObject] = GameObjectDB.get_db().get_from_category(category)
	var groups: Dictionary[String, LDObjectBrowserGroup]
	
	for obj: GameObject in objects:
		if not obj.ld_indexable:
			continue
		
		var group_name: String = obj.group_path.get_file()
		var group_node: LDObjectBrowserGroup
		
		if not groups.has(group_name):
			group_node = OBJECT_GROUP_SCENE.instantiate()
			group_node.set_group_name(group_name)
			groups.set(group_name, group_node)
			groups_v_box.add_child(group_node)
			group_node.entry_selected.connect(_on_entry_selected)
		else:
			group_node = groups.get(group_name)
		
		group_node.add_entry(obj)
	
	category_changed.emit(GameObject.get_category_name(category).to_pascal_case())


func _on_entry_selected(obj: GameObject) -> void:
	LD.get_object_handler().select_object(obj)
	hide_request.emit()


func _on_entities_category_toggled(toggled_on: bool) -> void:
	populate_list(GameObject.ObjectCategory.ENTITY)
	_play_sfx(toggled_on)


func _on_item_category_toggled(toggled_on: bool) -> void:
	populate_list(GameObject.ObjectCategory.ITEM)
	_play_sfx(toggled_on)


func _on_terrain_category_toggled(toggled_on: bool) -> void:
	populate_list(GameObject.ObjectCategory.TERRAIN)
	_play_sfx(toggled_on)


func _on_volumes_category_toggled(toggled_on: bool) -> void:
	populate_list(GameObject.ObjectCategory.VOLUME)
	_play_sfx(toggled_on)


func _on_hazards_category_toggled(toggled_on: bool) -> void:
	populate_list(GameObject.ObjectCategory.HAZARDS)
	_play_sfx(toggled_on)


func _on_props_category_toggled(toggled_on: bool) -> void:
	populate_list(GameObject.ObjectCategory.PROPS)
	_play_sfx(toggled_on)


func _on_triggers_category_toggled(toggled_on: bool) -> void:
	populate_list(GameObject.ObjectCategory.TRIGGER)
	_play_sfx(toggled_on)


func _play_sfx(toggled_on: bool) -> void:
	if toggled_on:
		SFX.play(SFX.UI_NEXT)
