extends PanelContainer

@export var group_list: HFlowContainer


func _on_toggle_group_button_toggled(toggled_on: bool) -> void:
	group_list.visible = toggled_on
	
	if toggled_on:
		SFX.play(SFX.UI_CONFIRM)
	else:
		SFX.play(SFX.UI_BACK)
