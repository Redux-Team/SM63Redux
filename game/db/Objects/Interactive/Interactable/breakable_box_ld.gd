@tool
extends LDObjectSprite


@export var coin_count_container: Node2D
@export var coin_count_label: Label


func _on_place() -> void:
	_update_coin_count(get_property("coin_amount"))


func _update_coin_count(amount: int) -> void:
	if amount <= 0:
		coin_count_container.hide()
		return
	
	coin_count_container.show()
	coin_count_label.text = "x" + str(amount)


func _on_property_changed(key: StringName, value: Variant) -> void:
	if key != "coin_amount":
		return
		
	_update_coin_count(value)
