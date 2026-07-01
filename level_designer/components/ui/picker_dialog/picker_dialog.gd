class_name LDPickerDialog
extends MarginContainer


signal confirmed(stamp_id: String)
signal cancelled


@export var option_button: OptionButton
@export var ok_button: Button
@export var cancel_button: Button


func _ready() -> void:
	ok_button.pressed.connect(_on_ok_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)


func setup(title: String, stamps: Array[LDStamp]) -> void:
	var ids: Array[String] = []
	for stamp: LDStamp in stamps:
		ids.append(stamp.id)
	setup_ids(title, ids)


func setup_ids(title: String, ids: Array[String]) -> void:
	option_button.clear()
	for id: String in ids:
		option_button.add_item(id)
		option_button.set_item_metadata(option_button.item_count - 1, id)


func _on_ok_pressed() -> void:
	if option_button.item_count == 0:
		return
	confirmed.emit(option_button.get_item_metadata(option_button.selected))


func _on_cancel_pressed() -> void:
	cancelled.emit()
