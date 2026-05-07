@tool
extends State


func _on_enter() -> void:
	print("IDLE!")
	await get_tree().create_timer(2).timeout
	done()
