class_name LDObjectBrowserGroup
extends PanelContainer

@export var group_list: HFlowContainer
@export var toggle_group_button: Button

const ITEM_ENTRY = preload("uid://dwtx65wov5nfl")

func clear_entries() -> void:
	for n: Node in group_list.get_children(): n.queue_free()


func set_group_name(group_name: String) -> void:
	name = group_name
	toggle_group_button.text = group_name


func add_entry(obj: GameObject) -> void:
	var entry: LDObjectItemEntry = ITEM_ENTRY.instantiate()
	entry.obj_ref = obj
	group_list.add_child(entry)


func _on_toggle_group_button_toggled(toggled_on: bool) -> void:
	group_list.visible = toggled_on
	
	if toggled_on:
		SFX.play(SFX.UI_CONFIRM)
	else:
		SFX.play(SFX.UI_BACK)
