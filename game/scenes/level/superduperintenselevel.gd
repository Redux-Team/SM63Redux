extends Node2D

@export var son: Player

var finale_started: bool = false


func _ready() -> void:
	move_to_checkpoint()


func move_to_checkpoint() -> void:
	match Singleton.get_meta("checkpoint"):
		1: son.position = Vector2(9824.0, -632.0)
		2: son.position = Vector2(21459.0, -1006.0)


func finale() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel()
	tween.tween_property($AudioStreamPlayer, "volume_db", -99, 5)
	tween.tween_property($CanvasLayer/ColorRect2, "color", Color.BLACK, 2)
	await tween.finished
	
	tween = create_tween()
	tween.tween_property($CanvasLayer/TextureRect, "self_modulate", Color.WHITE, 30)
	await get_tree().create_timer(3).timeout
	get_tree().change_scene_to_file("res://game/scenes/level/superawesomefinale.tscn")


func _on_player_ded() -> void:
	$AudioStreamPlayer.stop()
	$CanvasLayer/ColorRect.show()
	await get_tree().create_timer(4).timeout

	if not is_inside_tree():
		return

	get_tree().change_scene_to_file("res://game/scenes/level/superduperintenselevel.tscn")


func _process(_delta: float) -> void:
	if not finale_started and son and son.position.y > 1000:
		son.kill()

# finale check
func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.owner is Player:
		finale_started = true
		finale()
		return
