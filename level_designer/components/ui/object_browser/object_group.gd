class_name LDObjectBrowserGroup
extends PanelContainer

@export var group_list: HFlowContainer
@export var toggle_group_button: Button


func clear_entries() -> void:
	for n: Node in group_list.get_children(): n.queue_free()


func set_group_name(group_name: String) -> void:
	name = group_name
	toggle_group_button.text = group_name


func add_entry(obj: GameObject) -> void:
	var cr: ColorRect = ColorRect.new()
	cr.color = Color.BLACK
	cr.custom_minimum_size = Vector2(48, 48)
	group_list.add_child(cr)
	
	var l: Label = Label.new()
	l.add_theme_font_size_override(&"font_size", 12)
	l.text = obj.id
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	l.custom_minimum_size = cr.custom_minimum_size
	cr.add_child(l)


func _on_toggle_group_button_toggled(toggled_on: bool) -> void:
	group_list.visible = toggled_on
	
	if toggled_on:
		SFX.play(SFX.UI_CONFIRM)
	else:
		SFX.play(SFX.UI_BACK)
