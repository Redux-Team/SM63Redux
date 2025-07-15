@tool
extends Button

signal cycle(index: int, last: int)

@export var cycle_strings: Array[String]
@export var current_iter: int:
	set(ci):
		var last: int = current_iter
		
		current_iter = wrapi(ci, 0, cycle_strings.size())
		
		if last != current_iter:
			cycle.emit(current_iter, last)
		
		if cycle_strings:
			label.text = cycle_strings[current_iter]
@export var play_sound: bool = true

@export_group("Internal")
@export var label: Label


func _ready() -> void:
	label.text = cycle_strings[current_iter]
	cycle.connect(_on_cycle)


func _pressed() -> void:
	current_iter += 1


func _on_cycle(_index: int, _last: int) -> void:
	if play_sound and not Engine.is_editor_hint():
		SFX.play(SFX.UI_CONFIRM)
