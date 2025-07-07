@tool
class_name InputSettingEntry
extends SettingEntry


@export var input_name: String
@export var input_events: Array[InputEvent]

@export_group("Internal")
@export var input_name_label: Label
@export var input_events_label: Label



func _ready() -> void:
	input_name_label.text = input_name
	
	var events: PackedStringArray = []
	
	for event: InputEvent in input_events:
		events.append(event.as_text())
	
	input_events_label.text = ",".join(events)
