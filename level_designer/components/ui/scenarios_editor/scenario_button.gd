class_name LDScenarioButton
extends HBoxContainer

signal selected(scenario_id: int)

@export var select_button: Button
@export var delete_button: Button

var id: int:
	set(i):
		select_button.text = "Scenario %s" % i
		id = i


func _on_select_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		selected.emit(id)


func _on_delete_button_pressed() -> void:
	queue_free()
